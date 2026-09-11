-- Minerva Nail Art — initial schema.
--
-- Two tables:
--   profiles      one row per signed-in device, the customer's saved details
--   appointments  the bookings themselves, with a contact snapshot
--
-- The important part of this file is the partial unique index on
-- (slot_date, slot_hour): it is what makes double booking impossible, even
-- when two people tap "confirm" at the same instant. See the comment there.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type public.appointment_status as enum ('confirmed', 'cancelled');

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
-- Keyed by auth.uid(). Written the first time someone completes a booking,
-- which is how a "guest" becomes a known customer, and updated whenever they
-- book again with different details.

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  first_name  text        not null check (char_length(trim(first_name)) between 2 and 60),
  last_name   text        not null check (char_length(trim(last_name))  between 2 and 60),

  -- Ten significant digits, no country code or separators. The app's input
  -- mask produces exactly this; the constraint keeps anything else out.
  phone       text        not null check (phone ~ '^[1-9][0-9]{9}$'),

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Customer contact details, one row per authenticated device.';

-- ---------------------------------------------------------------------------
-- appointments
-- ---------------------------------------------------------------------------
-- Slots are stored as salon-local wall clock (a date plus an hour), NOT as an
-- instant.
--
-- This is deliberate. If the slot were a timestamptz computed on the device,
-- two phones set to different time zones would both turn "14:00" into a
-- different instant, and a uniqueness rule on that instant would happily let
-- both bookings through. The salon's day is wall clock — 14:00 means 14:00 in
-- the salon — so that is what gets stored and what uniqueness is enforced on.

create table public.appointments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,

  slot_date     date     not null,
  slot_hour     smallint not null check (slot_hour in (10, 12, 14, 16, 18, 20)),

  -- Null means the customer skipped the optional service step.
  service_id    text check (service_id in (
                  'classic_manicure', 'gel_manicure', 'nail_art_design', 'pedicure'
                )),

  -- Contact details as given at booking time. Kept alongside the profile on
  -- purpose: the profile is "who they are now", this is "who booked this".
  first_name    text not null check (char_length(trim(first_name)) between 2 and 60),
  last_name     text not null check (char_length(trim(last_name))  between 2 and 60),
  phone         text not null check (phone ~ '^[1-9][0-9]{9}$'),

  status        public.appointment_status not null default 'confirmed',

  created_at    timestamptz not null default now(),
  cancelled_at  timestamptz,

  constraint cancelled_at_matches_status check (
    (status = 'cancelled' and cancelled_at is not null) or
    (status = 'confirmed' and cancelled_at is null)
  )
);

comment on table public.appointments is
  'Bookings. One confirmed booking per salon-local slot, enforced by index.';

-- === The concurrency guard ==================================================
-- Postgres evaluates a unique index inside the insert's own transaction, so of
-- two simultaneous inserts for the same slot exactly one commits and the other
-- fails with SQLSTATE 23505. There is no window between "check" and "insert"
-- for a second booking to slip through — which is precisely why this is a
-- database constraint and not an application-level check.
--
-- It is partial so that cancelling a booking releases the slot again: a
-- cancelled row keeps its (slot_date, slot_hour) but drops out of the index.
--
-- Raise the salon's capacity by replacing this with a per-chair unique index
-- (add a chair/staff column and include it in the key).
create unique index appointments_one_confirmed_per_slot
  on public.appointments (slot_date, slot_hour)
  where status = 'confirmed';

-- Supports "my appointments", newest slot first.
create index appointments_user_slot_idx
  on public.appointments (user_id, slot_date desc, slot_hour desc);

-- ---------------------------------------------------------------------------
-- Reject bookings in the past, server-side
-- ---------------------------------------------------------------------------
-- The client already hides past slots, but a device with a wrong clock (or a
-- direct API call) must not be able to book yesterday.
--
-- The error code is deliberately NOT 'check_violation' (23514). The table's own
-- CHECK constraints — phone, name length, slot_hour, service_id — raise 23514
-- too, so a client that mapped 23514 to "that slot has already started" would
-- tell the customer the wrong thing whenever one of those failed. 'MN001' is a
-- user-defined SQLSTATE owned by this trigger alone, so the mapping in
-- `supabase_booking_repository.dart` is exact.
--
-- PostgREST passes the SQLSTATE through as the `code` field of the error body,
-- and maps anything it does not recognise to HTTP 400 — the same status 23514
-- produced before, so nothing else about the response changes.

create or replace function public.reject_past_appointments()
returns trigger
language plpgsql
as $$
declare
  salon_now timestamp := (now() at time zone 'Europe/Istanbul');
begin
  if new.status = 'confirmed'
     and (new.slot_date + make_interval(hours => new.slot_hour)) <= salon_now then
    raise exception 'Cannot book a slot in the past'
      using errcode = 'MN001';
  end if;
  return new;
end;
$$;

create trigger appointments_reject_past
  before insert on public.appointments
  for each row execute function public.reject_past_appointments();

-- ---------------------------------------------------------------------------
-- Keep profiles.updated_at honest
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------
-- Everyone sees only their own rows. Nobody can read anyone else's name or
-- phone number, which is why availability is served by the function below
-- rather than by selecting from this table.

alter table public.profiles     enable row level security;
alter table public.appointments enable row level security;

create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);

create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = id);

create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy appointments_select_own on public.appointments
  for select using (auth.uid() = user_id);

create policy appointments_insert_own on public.appointments
  for insert with check (auth.uid() = user_id);

-- Update is how a booking gets cancelled. Restricted to own rows; the
-- constraint above stops a row being "un-cancelled" without a timestamp.
create policy appointments_update_own on public.appointments
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Deliberately no delete policy: bookings are cancelled, never erased, so the
-- salon keeps its history.

-- ---------------------------------------------------------------------------
-- Availability, without leaking anyone's details
-- ---------------------------------------------------------------------------
-- The booking screen needs to know which slots are taken, including slots
-- taken by other people — but it must never see who took them. This function
-- runs as its owner (security definer) and returns nothing but the slot keys,
-- so RLS on the table stays strict while availability still works.

create or replace function public.booked_slots(from_date date, to_date date)
returns table (slot_date date, slot_hour smallint)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select a.slot_date, a.slot_hour
  from public.appointments a
  where a.status = 'confirmed'
    and a.slot_date >= from_date
    and a.slot_date <= to_date;
$$;

comment on function public.booked_slots(date, date) is
  'Taken slots in a date range. Returns slot keys only, never customer data.';

revoke all on function public.booked_slots(date, date) from public, anon;
grant execute on function public.booked_slots(date, date) to authenticated;
