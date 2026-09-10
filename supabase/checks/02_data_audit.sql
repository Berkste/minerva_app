-- Minerva Nail Art — data audit.
--
-- Read-only. Run this after `01_schema_audit.sql` comes back clean. It answers
-- the other half of "is this project fit to go live": what is actually stored
-- in it, whether the invariants have held so far, and how much of the content
-- is development leftovers.
--
-- Run each section on its own — the SQL editor shows the last statement's
-- result, so running the whole file at once only displays section 8.

-- ---------------------------------------------------------------------------
-- 1. Has the uniqueness guarantee actually held?
-- ---------------------------------------------------------------------------
-- The one query that matters most. Every row returned is a slot the salon
-- double-booked, and would mean the index has not been doing its job.
-- Expected: no rows.

select slot_date, slot_hour, count(*) as confirmed_bookings,
       string_agg(id::text, ', ') as appointment_ids
from public.appointments
where status = 'confirmed'
group by slot_date, slot_hour
having count(*) > 1
order by slot_date, slot_hour;

-- ---------------------------------------------------------------------------
-- 2. Shape of the stored data
-- ---------------------------------------------------------------------------

select
  (select count(*) from public.appointments)                                as appointments_total,
  (select count(*) from public.appointments where status = 'confirmed')     as confirmed,
  (select count(*) from public.appointments where status = 'cancelled')     as cancelled,
  (select count(*) from public.appointments
     where status = 'confirmed' and slot_date >= current_date)              as confirmed_upcoming,
  (select count(*) from public.profiles)                                    as profiles,
  (select count(*) from public.admins)                                      as admins,
  (select count(*) from auth.users)                                         as auth_users,
  (select min(created_at) from public.appointments)                         as first_booking,
  (select max(created_at) from public.appointments)                         as last_booking;

-- ---------------------------------------------------------------------------
-- 3. Who is in auth.users — anonymous customers vs staff logins
-- ---------------------------------------------------------------------------
-- Anonymous users are devices that opened the customer app. In a development
-- project most of them are yours and the concurrency probe's; in a live one
-- they are real customers. This is the line the cleanup in 03 deletes along.
--
-- If `auth.users.is_anonymous` does not exist on this instance (older auth
-- versions), use this instead — an anonymous user has no identity row:
--
--   select case when i.user_id is null then 'anonymous (customer device)'
--               else 'has an identity (staff)' end as kind, count(*)
--   from auth.users u
--   left join (select distinct user_id from auth.identities) i on i.user_id = u.id
--   group by 1;

select
  case
    when coalesce(u.is_anonymous, false) then 'anonymous (customer device)'
    when u.email is not null              then 'email login (staff)'
    else 'other'
  end                                                as kind,
  count(*)                                           as users,
  min(u.created_at)                                  as first_seen,
  max(u.created_at)                                  as last_seen,
  count(*) filter (where a.user_id is not null)      as users_with_bookings
from auth.users u
left join lateral (
  select 1 as user_id from public.appointments ap where ap.user_id = u.id limit 1
) a on true
group by 1
order by 2 desc;

-- ---------------------------------------------------------------------------
-- 4. The staff roster — every row here reads every customer's phone number
-- ---------------------------------------------------------------------------
-- Check this line by line before going live. A leftover development admin is
-- a standing privacy hole, not an untidiness.

select ad.id,
       u.email,
       u.email_confirmed_at is not null as email_confirmed,
       u.last_sign_in_at,
       ad.created_at as admin_since
from public.admins ad
left join auth.users u on u.id = ad.id
order by ad.created_at;

-- ---------------------------------------------------------------------------
-- 5. Bookings that look like development leftovers
-- ---------------------------------------------------------------------------
-- The concurrency probe books one slot from many users at once, so its traces
-- are bursts of same-second inserts. Real customers do not arrive that way.

select date_trunc('second', created_at) as inserted_at,
       count(*)                         as rows_in_that_second,
       count(distinct user_id)          as distinct_users,
       string_agg(distinct status::text, ', ') as statuses
from public.appointments
group by 1
having count(*) > 1
order by 2 desc, 1 desc
limit 50;

-- ---------------------------------------------------------------------------
-- 6. Rows the app can no longer reach
-- ---------------------------------------------------------------------------
-- Bookings whose owner has no profile: a device that booked before the profile
-- write, or one whose user was removed. Not an error, but worth seeing.

select count(*) filter (where p.id is null) as bookings_without_profile,
       count(*) filter (where ap.slot_date < current_date
                          and ap.status = 'confirmed') as past_confirmed_bookings,
       count(*) as total
from public.appointments ap
left join public.profiles p on p.id = ap.user_id;

-- ---------------------------------------------------------------------------
-- 7. Do the stored values still satisfy the app's rules?
-- ---------------------------------------------------------------------------
-- The constraints enforce these on write, so rows can only violate them if a
-- constraint was added after the data, or dropped and re-added. Expected: 0.

select
  count(*) filter (where phone !~ '^[1-9][0-9]{9}$')                    as bad_phone,
  count(*) filter (where slot_hour not in (10, 12, 14, 16, 18, 20))     as bad_hour,
  count(*) filter (where service_id is not null and service_id not in (
    'classic_manicure', 'gel_manicure', 'nail_art_design', 'pedicure'))  as unknown_service,
  count(*) filter (where status = 'cancelled' and cancelled_at is null)  as cancelled_without_timestamp,
  count(*) filter (where status = 'confirmed' and cancelled_at is not null) as confirmed_with_timestamp
from public.appointments;

-- ---------------------------------------------------------------------------
-- 8. Storage and load, so the plan can be judged
-- ---------------------------------------------------------------------------

select relname                                        as table_name,
       n_live_tup                                     as approx_rows,
       pg_size_pretty(pg_total_relation_size(relid))  as total_size
from pg_stat_user_tables
where schemaname = 'public'
order by pg_total_relation_size(relid) desc;
