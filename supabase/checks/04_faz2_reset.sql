-- Minerva Nail Art — clearing the old schema before the phase 2 rebuild.
--
-- ⚠️ DESTRUCTIVE. This drops every object the previous schema created, with
-- everything in them. Read this header before running a single line.
--
-- Why this exists as a separate file: migrations create, they never destroy.
-- Keeping the drops here means re-running a migration can never cost data, and
-- that wiping the schema is always something a person chose to do.
--
-- ---------------------------------------------------------------------------
-- Is it safe to run?
-- ---------------------------------------------------------------------------
-- Only while the project has no real customers. The audit on 2026-09-11 found
-- zero bookings, zero profiles and one staff account — that is the state this
-- was written for, and the whole reason phase 2 is being done now rather than
-- later.
--
-- Check again before running, because time has passed:

select
  (select count(*) from public.appointments)                       as appointments,
  (select count(*) from public.profiles)                           as profiles,
  (select count(*) from auth.users where coalesce(is_anonymous, false)) as anonymous_users,
  (select count(*) from public.admins)                             as staff;

-- Expected: 0 appointments, 0 profiles, 0 anonymous users, 1 staff.
-- Anything else means somebody has used the app. **Stop** and say so — the
-- rebuild would take their bookings with it.
--
-- ---------------------------------------------------------------------------
-- What survives
-- ---------------------------------------------------------------------------
-- `auth.users` is untouched, so the staff login survives. Its `admins` row does
-- not — that table is dropped and recreated with the rest, so section 3 below
-- puts the row back. Until it does, the admin app cannot get in.
--
-- The Supabase project itself, its URL, its keys and its dashboard settings are
-- all unaffected. Only the contents of the `public` schema change.


-- ===========================================================================
-- Section 1 — drop the old schema
-- ===========================================================================
-- `cascade` on the tables takes their policies, indexes, constraints and
-- triggers with them. The functions and the enum have to go by name.
--
-- Uncomment and run.

/*
begin;

drop table if exists public.appointments cascade;
drop table if exists public.profiles     cascade;
drop table if exists public.admins       cascade;

drop function if exists public.booked_slots(date, date);
drop function if exists public.is_admin();
drop function if exists public.reject_past_appointments();
drop function if exists public.touch_updated_at();

drop type if exists public.appointment_status;

commit;
*/


-- ===========================================================================
-- Section 2 — build the new schema
-- ===========================================================================
-- Paste and run, in this order:
--
--   supabase/migrations/20260921120000_schema.sql
--   supabase/migrations/20260921120100_catalogue.sql
--
-- The second one ends with a summary select; expect 7 rows of kind=main and
-- 8 of kind=extra.


-- ===========================================================================
-- Section 3 — put the staff account back
-- ===========================================================================
-- The login itself never went anywhere; only its membership row did.

/*
insert into public.admins (id)
values ('8ee7ffc9-b007-46ac-b6a8-7dd2d69fec44')
on conflict (id) do nothing;
*/

-- Verify — exactly one row, admin@minerva.com.tr:

select ad.id, u.email, ad.created_at as admin_since
from public.admins ad
left join auth.users u on u.id = ad.id;


-- ===========================================================================
-- Section 4 — confirm
-- ===========================================================================
-- Run `supabase/checks/01_schema_audit.sql`. Zero FAIL is the finish line.
--
-- After that, this file has done its job. Do not run section 1 again: from the
-- first real booking onwards it destroys the salon's records.
