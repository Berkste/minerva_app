-- Minerva Nail Art — admin / employee access.
--
-- Adds a staff role on top of the customer schema WITHOUT touching any of the
-- existing customer policies. Customers keep seeing only their own rows; this
-- file only grants staff the extra reach to run the salon.
--
-- The whole admin capability is enforced here, in the database. The Flutter
-- app's "am I an admin" check is a convenience for showing the right screen —
-- it is NOT the security boundary. Even a tampered client cannot read or cancel
-- another customer's booking unless the caller is actually in `admins`.

-- ---------------------------------------------------------------------------
-- admins
-- ---------------------------------------------------------------------------
-- One row per staff member, keyed by their auth user id. Membership is granted
-- by hand in the SQL editor (or by an existing admin via the service role) —
-- there is deliberately no self-service "become an admin" path.

create table public.admins (
  id          uuid primary key references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

comment on table public.admins is
  'Staff user ids. Membership grants read/manage over all appointments.';

-- ---------------------------------------------------------------------------
-- is_admin(): is the current caller staff?
-- ---------------------------------------------------------------------------
-- security definer on purpose. The appointments policies below call this to
-- decide "can this caller see everything". If the function were a
-- plain query against public.admins, and admins itself had a policy that also
-- called is_admin(), Postgres would recurse. Running as owner (bypassing RLS on
-- admins) and keeping the admins policy free of is_admin() breaks that cycle.
--
-- search_path is pinned so the definer-rights function cannot be tricked into
-- resolving `admins` to some other schema.

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.admins a where a.id = auth.uid()
  );
$$;

comment on function public.is_admin() is
  'True when the current auth.uid() is a staff member. Used by RLS policies.';

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Row level security on admins
-- ---------------------------------------------------------------------------
-- A staff member may read their OWN row (so the app can answer "am I staff?"),
-- but the table is not enumerable — one admin cannot list the others. There is
-- no client insert/update/delete policy at all: the roster is managed only from
-- the SQL editor or the service role, never from the app.

alter table public.admins enable row level security;

create policy admins_select_self on public.admins
  for select using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- Extra reach for staff over the existing tables
-- ---------------------------------------------------------------------------
-- These are ADDITIONAL policies. RLS combines policies with OR, so the existing
-- customer "own rows" policies still apply unchanged for everyone; staff simply
-- gain a second way in. Nothing here weakens a customer's isolation.

-- Staff can read every appointment (to run the day's schedule)…
create policy appointments_select_admin on public.appointments
  for select using (public.is_admin());

-- …and cancel any of them. The existing cancelled_at/status check constraint
-- still holds, so a staff update must set cancelled_at when it flips the status
-- to 'cancelled' — same rule as a customer cancelling their own. Cancelling
-- frees the slot through the existing partial unique index; no second mechanism.
create policy appointments_update_admin on public.appointments
  for update using (public.is_admin()) with check (public.is_admin());

-- Deliberately NO staff policy on `profiles`. It looks like staff would need one
-- to see who is coming, but they do not: every booking carries its own
-- first_name / last_name / phone, snapshotted onto the appointment row when the
-- customer confirmed it, and the admin screens read only that. The two calls
-- that touch `profiles` (`fetchProfile` and `saveProfile`) are both scoped to
-- `auth.uid()` and are served by profiles_select_own.
--
-- So a staff-wide read on `profiles` would hand every staff member the current
-- phone number of every customer who ever registered — including those with no
-- booking at all — and buy nothing. Left out on least-privilege grounds. If a
-- screen ever genuinely needs the live profile rather than the snapshot, add it
-- back knowingly, together with that screen.

-- No admin INSERT policy on appointments and no DELETE anywhere: staff manage
-- existing bookings, they do not create them for customers or erase history in
-- this release. Add those deliberately if the salon workflow needs them.
