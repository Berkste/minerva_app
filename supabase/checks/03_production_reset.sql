-- Minerva Nail Art — turning this project into the live one.
--
-- ⚠️ DESTRUCTIVE. Every statement below deletes something. Read the section
-- you are about to run, run only that section, and never run this file whole.
--
-- Context: this project was the development project. Its content is test data
-- and its schema was reached by applying migrations, patching a partly-applied
-- one, and re-running — not by a clean pass. Both are fixable while the data is
-- still disposable, which is exactly now.
--
-- Two ways forward. A is stronger and costs about the same today.
--
--   A. Clean re-apply — drop the app's objects and run the two migration files
--      from scratch, so the live schema is provably the schema in git.
--   B. Data-only cleanup — keep the schema as it stands and delete the test
--      rows and test users. Choose this only if 01_schema_audit.sql came back
--      with no FAILs.
--
-- Whichever you pick, section 3 (auth users) and section 4 (staff roster) apply
-- to both.


-- ===========================================================================
-- Section 0 — before anything: know what you are deleting
-- ===========================================================================
-- Run 02_data_audit.sql first. If any of it surprises you, stop.
--
-- If you want a copy of the current content before dropping it, the Supabase
-- dashboard's Database → Backups can take one, or export the two tables from
-- the Table Editor. There is nothing here worth keeping, but a backup you did
-- not need beats the reverse.


-- ===========================================================================
-- Section A — clean re-apply (recommended)
-- ===========================================================================
-- Drops every object the two migrations create, in dependency order. Uncomment
-- the block, run it, then paste and run — in this order —
--
--   supabase/migrations/20260827120000_init.sql
--   supabase/migrations/20260828120000_admin.sql
--
-- and finish with section 3 and section 4 below. Then re-run
-- 01_schema_audit.sql: everything should be OK, and this time the schema's
-- provenance is the repository rather than a sequence of patches.

/*
begin;

drop trigger if exists appointments_reject_past   on public.appointments;
drop trigger if exists profiles_touch_updated_at  on public.profiles;

drop table if exists public.appointments cascade;   -- takes its policies,
drop table if exists public.profiles     cascade;   -- indexes and constraints
drop table if exists public.admins       cascade;   -- with it

drop function if exists public.booked_slots(date, date);
drop function if exists public.is_admin();
drop function if exists public.reject_past_appointments();
drop function if exists public.touch_updated_at();

drop type if exists public.appointment_status;

commit;
*/

-- After re-applying both migrations the `admins` table is empty again. Nobody
-- can reach the staff screens until you add rows in section 4.


-- ===========================================================================
-- Section B — data-only cleanup (if you keep the current schema)
-- ===========================================================================
-- Deletes the bookings and profiles without touching the schema. Note that
-- section 3 already removes these by cascade when it deletes the anonymous
-- users that own them — this section is only for the case where you want to
-- clear the tables but keep the users.

/*
begin;

delete from public.appointments;
delete from public.profiles;

commit;
*/


-- ===========================================================================
-- Section 3 — remove the test customer accounts
-- ===========================================================================
-- Every anonymous user is one device that opened the customer app during
-- development, including the pool the concurrency probe created. Deleting them
-- cascades to their profiles and appointments (`on delete cascade`), so this is
-- also the cleanest way to empty the tables.
--
-- Look before you delete:

select count(*) as anonymous_users_to_delete
from auth.users
where coalesce(is_anonymous, false);

-- Then, once that number is the one you expect:

/*
delete from auth.users where coalesce(is_anonymous, false);
*/

-- This is safe to run only while the project has no real customers — after
-- go-live the same statement deletes every customer the salon has.


-- ===========================================================================
-- Section 4 — the staff roster, decided deliberately
-- ===========================================================================
-- Membership of `admins` is the whole of staff authorization: each row can read
-- every customer's name and phone number and cancel any booking. There is no
-- self-service path into it by design, so it is entirely yours to curate.
--
-- Who is in it now, and who they are:

select ad.id, u.email, u.last_sign_in_at, ad.created_at as admin_since
from public.admins ad
left join auth.users u on u.id = ad.id
order by ad.created_at;

-- Remove a development account:

/*
delete from public.admins where id = '<uuid>';
*/

-- Add a real staff member. First create the user in the dashboard
-- (Authentication → Users → Add user, with a real address and Auto Confirm),
-- then grant them staff access by id:

/*
insert into public.admins (id)
select id from auth.users where email = 'staff@example.com'
on conflict (id) do nothing;
*/

-- Verify that nothing unintended survived:

select count(*) as staff_members from public.admins;


-- ===========================================================================
-- Section 5 — what SQL cannot check
-- ===========================================================================
-- These live in the dashboard, not the database, and none of them are visible
-- to the audit scripts:
--
--   Authentication → Sign In / Providers
--     · Anonymous sign-ins ON        — the customer app cannot sign in without it
--     · Email provider ON            — staff log in with email + password
--     · Confirm email                — staff accounts are created by hand, so
--                                      Auto Confirm on creation is fine
--     · Password policy / leaked password protection — staff accounts hold
--                                      access to every customer's details
--   Authentication → Rate limits     — anonymous sign-ups are one per install;
--                                      the default burst limit is what stopped
--                                      the concurrency probe, not a bug
--   Database → Backups               — free tier has no point-in-time recovery.
--                                      Real customer names and phone numbers
--                                      are personal data; decide the plan and
--                                      the retention before, not after
--   Project → General                — a free project pauses after 7 days of
--                                      inactivity. A quiet week at the salon
--                                      would take the app down
--   API → Exposed schemas            — `public` only; nothing else should be
--                                      reachable through PostgREST
--   Project → API keys               — the publishable/anon key is meant to be
--                                      public and is safe in the app. The
--                                      service_role key is not: it bypasses
--                                      RLS entirely and must never appear in
--                                      the app, in git, or in a build command
