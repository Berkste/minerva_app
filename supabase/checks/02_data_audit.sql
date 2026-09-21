-- Minerva Nail Art — data audit.
--
-- Read-only. Run the sections one at a time and read each result; unlike the
-- schema audit this one is meant to be looked at, not scanned for the word
-- FAIL. Nothing here writes anything.
--
-- Where `01_schema_audit.sql` asks "is the schema what the app expects", this
-- asks "is what is actually stored consistent with the rules". A rule can be
-- in force from today and still have rows from before it that break it.

-- ===========================================================================
-- 1. The one that must come back empty
-- ===========================================================================
-- Two live appointments in the same slot. The partial unique index makes this
-- impossible, so a row here means the index is missing or was dropped — the
-- single worst thing that can happen to this database.

select slot_date, slot_hour, count(*) as clashes,
       string_agg(id::text, ', ') as appointment_ids
from public.appointments
where status in ('confirmed', 'completed') and deleted_at is null
group by slot_date, slot_hour
having count(*) > 1
order by slot_date, slot_hour;


-- ===========================================================================
-- 2. Shape of the data
-- ===========================================================================

select
  (select count(*) from public.customers where deleted_at is null)            as customers,
  (select count(*) from public.customers where deleted_at is not null)        as customers_archived,
  (select count(*) from public.customer_devices)                              as linked_devices,
  (select count(*) from public.appointments where deleted_at is null)         as appointments,
  (select count(*) from public.appointments
    where status = 'confirmed' and deleted_at is null
      and slot_date >= current_date)                                          as upcoming,
  (select count(*) from public.appointments where status = 'cancelled')       as cancelled,
  (select count(*) from public.appointments where status = 'no_show')         as no_shows,
  (select count(*) from public.services where deleted_at is null)             as services,
  (select count(*) from public.salon_closures where deleted_at is null)       as closures,
  (select count(*) from public.admins)                                        as staff,
  (select count(*) from auth.users)                                           as auth_users;


-- ===========================================================================
-- 3. The 21-day rule, checked against what is stored
-- ===========================================================================
-- The trigger enforces this going forward and exempts staff-created bookings.
-- This finds customers who nonetheless hold two live appointments closer than
-- 21 days — which is legitimate when the salon put one of them in, and worth a
-- look when it did not.

select c.phone,
       c.first_name,
       a.slot_date    as first_date,
       b.slot_date    as second_date,
       (b.slot_date - a.slot_date) as days_apart,
       a.created_by_admin as first_by_admin,
       b.created_by_admin as second_by_admin
from public.appointments a
join public.appointments b
  on b.customer_id = a.customer_id
 and b.id <> a.id
 and b.slot_date > a.slot_date
 and (b.slot_date - a.slot_date) < 21
join public.customers c on c.id = a.customer_id
where a.status in ('confirmed', 'completed') and a.deleted_at is null
  and b.status in ('confirmed', 'completed') and b.deleted_at is null
order by days_apart, c.phone;


-- ===========================================================================
-- 4. Bookings on days the salon is shut
-- ===========================================================================
-- Sundays and declared closures. Staff bookings are allowed here by design, so
-- the created_by_admin column is the thing to read.

select a.slot_date,
       to_char(a.slot_date, 'Day')          as weekday,
       a.slot_hour,
       a.created_by_admin,
       case when extract(isodow from a.slot_date) = 7 then 'Sunday'
            else 'declared closure' end     as reason
from public.appointments a
where a.status in ('confirmed', 'completed') and a.deleted_at is null
  and (
    extract(isodow from a.slot_date) = 7
    or exists (
      select 1 from public.salon_closures c
      where c.deleted_at is null and a.slot_date between c.start_date and c.end_date
    )
  )
order by a.slot_date;


-- ===========================================================================
-- 5. Identity consistency
-- ===========================================================================
-- Customers nobody can reach (no device ever linked), devices pointing at an
-- archived person, and appointments whose contact snapshot has drifted from
-- the customer record. None of these are errors on their own — a customer the
-- salon created by hand has no device until that person installs the app.

select 'customer with no linked device'            as finding,
       count(*)                                    as rows
from public.customers c
where c.deleted_at is null
  and not exists (select 1 from public.customer_devices d where d.customer_id = c.id)

union all
select 'device pointing at an archived customer',
       count(*)
from public.customer_devices d
join public.customers c on c.id = d.customer_id
where c.deleted_at is not null

union all
select 'appointment phone differs from customer phone',
       count(*)
from public.appointments a
join public.customers c on c.id = a.customer_id
where a.phone is distinct from c.phone and a.deleted_at is null;


-- ===========================================================================
-- 6. Field-level invariants
-- ===========================================================================
-- Everything the CHECK constraints already guarantee, verified rather than
-- assumed. All zeros is the expected answer.

select
  (select count(*) from public.customers
    where phone !~ '^[1-9][0-9]{9}$')                                          as bad_customer_phone,
  (select count(*) from public.appointments
    where phone !~ '^[1-9][0-9]{9}$')                                          as bad_appointment_phone,
  (select count(*) from public.appointments
    where slot_hour not in (10, 12, 14, 16, 18, 20))                           as bad_hour,
  (select count(*) from public.appointments
    where status = 'cancelled' and (cancelled_at is null or cancelled_by is null)) as cancelled_without_who_or_when,
  (select count(*) from public.appointments
    where status <> 'cancelled' and (cancelled_at is not null or cancelled_by is not null)) as not_cancelled_but_marked,
  (select count(*) from public.appointment_services s
    where s.deleted_at is null
      and not exists (select 1 from public.services sv where sv.id = s.service_id)) as orphan_line_items;


-- ===========================================================================
-- 7. The catalogue
-- ===========================================================================
-- What the salon is currently offering, and what each appointment is worth.
-- Revenue is the sum of the line items, never derived from the catalogue —
-- two extras are priced as a range, so only the recorded figure is true.

select kind,
       count(*)                                      as services,
       min(price_min)                                as cheapest,
       max(coalesce(price_max, price_min))           as dearest,
       count(*) filter (where price_max is not null) as ranged
from public.services
where deleted_at is null
group by kind
order by kind;

-- Appointments with money on them, most recent first.

select a.slot_date,
       a.slot_hour,
       a.status,
       count(s.id)                          as line_items,
       coalesce(sum(s.amount), 0)           as total
from public.appointments a
left join public.appointment_services s
  on s.appointment_id = a.id and s.deleted_at is null
where a.deleted_at is null
group by a.id, a.slot_date, a.slot_hour, a.status
order by a.slot_date desc, a.slot_hour desc
limit 50;


-- ===========================================================================
-- 8. Who can reach everything
-- ===========================================================================
-- Membership of `admins` is the whole of staff authorization: each row can
-- read every customer's name and phone number and change any booking.

select ad.id, u.email, u.last_sign_in_at, ad.created_at as admin_since
from public.admins ad
left join auth.users u on u.id = ad.id
order by ad.created_at;


-- ===========================================================================
-- 9. Size
-- ===========================================================================

select relname as table_name,
       n_live_tup as approx_rows,
       pg_size_pretty(pg_total_relation_size(relid)) as total_size
from pg_stat_user_tables
where schemaname = 'public'
order by pg_total_relation_size(relid) desc;
