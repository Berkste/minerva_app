-- Minerva Nail Art — complete schema.
--
-- This file supersedes 20260827120000_init.sql, 20260828120000_admin.sql and
-- 20260911120000_browse_before_signin.sql, which are in git history. The
-- schema was consolidated rather than patched because the phase 2 design
-- replaces most of it: customers become their own table, appointments hang off
-- them instead of off auth.users, and the service catalogue moves from a CHECK
-- constraint into real rows.
--
-- Apply order:
--   1. supabase/checks/04_faz2_reset.sql   (destructive — drops the old schema)
--   2. this file
--   3. 20260921120100_catalogue.sql        (the service catalogue as data)
--
-- Nothing here deletes anything: the drops live in the checks/ script so that
-- re-running a migration can never destroy data.
--
-- The design decisions behind this file are recorded in FAZ2_ANALIZ.md.

-- ===========================================================================
-- Types
-- ===========================================================================

-- confirmed → the slot is held.
-- completed → the appointment happened. Also *derived* for a confirmed row an
--             hour past its slot (see the note on the booking window below),
--             so the salon never has to mark the ordinary case by hand.
-- cancelled → called off, by the customer or by staff. Frees the slot.
-- no_show   → the customer did not come. Frees the slot AND releases them from
--             the booking window, because they received no service.
create type public.appointment_status as enum (
  'confirmed', 'cancelled', 'completed', 'no_show'
);

-- A treatment the customer can book, or an add-on only the salon records.
create type public.service_kind as enum ('main', 'extra');

-- Who performed an action, where "the customer did it" and "staff did it" need
-- to be told apart after the fact.
create type public.actor as enum ('customer', 'admin');

-- ===========================================================================
-- customers — the person
-- ===========================================================================
-- The phone number identifies the person. There is no password and no OTP:
-- a device proves nothing beyond "somebody typed this number", which is why
-- claim_customer() below also requires the first name to match, and why a
-- claimed record shows only future appointments. That is friction, not
-- security, and it is a deliberate, recorded trade-off.
--
-- last_name is optional: only a first name and a phone number are required to
-- book.

create table public.customers (
  id            uuid primary key default gen_random_uuid(),

  first_name    text not null check (char_length(trim(first_name)) between 2 and 60),
  last_name     text check (last_name is null or char_length(trim(last_name)) between 2 and 60),
  phone         text not null check (phone ~ '^[1-9][0-9]{9}$'),

  -- True when staff created this person rather than the person themselves.
  created_by_admin boolean not null default false,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Soft delete. Nothing in this schema is ever really deleted; the app
  -- filters on this instead.
  deleted_at    timestamptz
);

-- One row per phone number, including soft-deleted ones. A returning customer
-- whose record was archived is revived rather than duplicated, so their
-- history — and their booking window — follows them.
create unique index customers_phone_key on public.customers (phone);

comment on table public.customers is
  'People. Identified by phone number. Survives device changes and reinstalls.';

-- ===========================================================================
-- customer_devices — which device is whom
-- ===========================================================================
-- An anonymous auth session is a device, not a person. This table is the link,
-- and it replaces the old `profiles` table entirely: name and phone moved to
-- customers, and all that was left was the association.
--
-- One person can accumulate several devices over time; each row is one device.

create table public.customer_devices (
  auth_user_id  uuid primary key references auth.users (id) on delete cascade,
  customer_id   uuid not null references public.customers (id) on delete cascade,
  linked_at     timestamptz not null default now()
);

create index customer_devices_customer_idx
  on public.customer_devices (customer_id);

comment on table public.customer_devices is
  'Anonymous auth user → customer. Replaces the old profiles table.';

-- ===========================================================================
-- services — the catalogue
-- ===========================================================================
-- Rows, not a CHECK constraint, so staff can change prices and retire
-- treatments without a migration.
--
-- price_max is null for a fixed price. Two extras are genuinely open-ended
-- (Nail Art, Charm/Taş — 20 to 300 TL), which is the whole reason revenue is
-- recorded per appointment rather than derived from this table.

create table public.services (
  id             text primary key,
  kind           public.service_kind not null,

  name_tr        text not null,
  name_en        text not null,
  description_tr text,
  description_en text,

  price_min      numeric(10, 2) not null check (price_min >= 0),
  price_max      numeric(10, 2) check (price_max is null or price_max >= price_min),
  currency       text not null default 'TRY',

  is_active      boolean not null default true,
  sort_order     integer not null default 0,

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

-- Lets appointment_services carry a composite foreign key, so a line item's
-- `kind` cannot disagree with the catalogue. See the note there.
alter table public.services
  add constraint services_id_kind_key unique (id, kind);

comment on table public.services is
  'Bookable treatments (kind=main) and add-ons the salon records (kind=extra).';

-- ===========================================================================
-- appointments
-- ===========================================================================

create table public.appointments (
  id            uuid primary key default gen_random_uuid(),
  customer_id   uuid not null references public.customers (id) on delete cascade,

  slot_date     date     not null,
  slot_hour     smallint not null check (slot_hour in (10, 12, 14, 16, 18, 20)),

  -- Contact details as given at booking time. Kept alongside the customer row
  -- on purpose: the customer record is "who they are now", this is "who booked
  -- this". Changing a phone number must not rewrite last year's bookings.
  first_name    text not null check (char_length(trim(first_name)) between 2 and 60),
  last_name     text check (last_name is null or char_length(trim(last_name)) between 2 and 60),
  phone         text not null check (phone ~ '^[1-9][0-9]{9}$'),

  status        public.appointment_status not null default 'confirmed',

  -- Stamped by a trigger, never by the client — see appointments_stamp_origin.
  -- created_by_admin is what the rules read: it is a plain boolean that
  -- survives the staff account being deleted, and a customer cannot set it,
  -- which matters because it exempts a row from the booking window.
  created_by       uuid references auth.users (id) on delete set null,
  created_by_admin boolean not null default false,

  cancelled_by  public.actor,
  cancelled_at  timestamptz,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,

  constraint cancelled_fields_match_status check (
    (status = 'cancelled' and cancelled_at is not null and cancelled_by is not null)
    or
    (status <> 'cancelled' and cancelled_at is null and cancelled_by is null)
  )
);

-- ---------------------------------------------------------------------------
-- The one guarantee the whole design rests on
-- ---------------------------------------------------------------------------
-- Two people cannot hold the same slot. Enforced by the database, not by the
-- app: the client never checks availability before inserting, it just inserts
-- and lets this index decide. Losing that race is a normal outcome.
--
-- The predicate covers 'completed' as well as 'confirmed', so marking an
-- appointment done never quietly frees its slot. 'cancelled' and 'no_show'
-- release it, which is the point of both.
create unique index appointments_one_active_per_slot
  on public.appointments (slot_date, slot_hour)
  where status in ('confirmed', 'completed') and deleted_at is null;

-- Supports "my appointments" and the customer's booking-window check.
create index appointments_customer_slot_idx
  on public.appointments (customer_id, slot_date desc, slot_hour desc);

-- Supports the admin month view and the statistics page.
create index appointments_slot_date_idx
  on public.appointments (slot_date);

-- ===========================================================================
-- appointment_services — what was actually done, and for how much
-- ===========================================================================
-- One money model for the whole system, and one list for staff to edit.
--
-- `amount` is a copy of the price at the moment of choosing, so changing the
-- catalogue never rewrites what a past appointment cost. An appointment's
-- total is the sum of its lines — there is deliberately no total column, since
-- the thing staff edit is the lines themselves and a stored total would be a
-- second copy of the same number, free to drift.

create table public.appointment_services (
  id             uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments (id) on delete cascade,

  -- Composite reference, so `kind` is guaranteed to be the catalogue's answer
  -- rather than whatever the client sent. That in turn lets the partial unique
  -- index below mean what it says.
  service_id     text not null,
  kind           public.service_kind not null,
  foreign key (service_id, kind) references public.services (id, kind),

  amount         numeric(10, 2) not null check (amount >= 0),
  created_at     timestamptz not null default now(),

  -- Soft delete here too. A line staff took off again is still a record of
  -- what was once charged, and the rule that nothing leaves this database is
  -- absolute rather than a rule with exceptions for small rows.
  deleted_at     timestamptz
);

-- A booking is one treatment plus any number of add-ons.
create unique index appointment_one_main_service
  on public.appointment_services (appointment_id)
  where kind = 'main' and deleted_at is null;

create index appointment_services_appointment_idx
  on public.appointment_services (appointment_id);

-- ===========================================================================
-- salon_closures — days the salon is shut
-- ===========================================================================
-- Sundays are not stored here; they are a standing rule in the trigger. This
-- table is for the exceptions staff declare: a single day, or a holiday that
-- runs from one date to another.

create table public.salon_closures (
  id          uuid primary key default gen_random_uuid(),
  start_date  date not null,
  end_date    date not null,
  reason      text,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz,

  constraint closure_range_valid check (end_date >= start_date)
);

create index salon_closures_range_idx
  on public.salon_closures (start_date, end_date);

-- ===========================================================================
-- Functions
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- is_admin(): is the caller staff?
-- ---------------------------------------------------------------------------
-- security definer on purpose, and the admins policy below deliberately does
-- not call it: a definer function reading admins while admins' own policy
-- called back into it would recurse.

create table public.admins (
  id          uuid primary key references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

comment on table public.admins is
  'Staff user ids. Membership grants read/manage over everything.';

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (select 1 from public.admins a where a.id = auth.uid());
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- current_customer_id(): which person is this device?
-- ---------------------------------------------------------------------------
-- Every customer-facing policy routes through here. Definer rights so it can
-- read customer_devices without that table needing a policy that would expose
-- the mapping itself.

create or replace function public.current_customer_id()
returns uuid
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select cd.customer_id
  from public.customer_devices cd
  where cd.auth_user_id = auth.uid();
$$;

revoke all on function public.current_customer_id() from public, anon;
grant execute on function public.current_customer_id() to authenticated;

-- ---------------------------------------------------------------------------
-- claim_customer(): find this person, or create them
-- ---------------------------------------------------------------------------
-- The only way a customer record is created from the app, and the only place
-- the name+phone match is enforced. It has to be a definer function: matching
-- by phone means reading rows the caller has no right to see, and doing that
-- through a table policy would expose every customer to a lookup.
--
-- Three outcomes:
--   · no such phone      → create the person, link this device
--   · phone + name match → link this device to the existing person
--   · phone, wrong name  → MN005, and nothing is revealed about the record
--
-- The name comparison is deliberately forgiving about case and surrounding
-- space but nothing else. It stops somebody working through phone numbers; it
-- does not stop somebody who knows whose number they are typing. That limit is
-- understood and accepted — see FAZ2_ANALIZ.md §4.

create or replace function public.claim_customer(
  p_first_name text,
  p_last_name  text,
  p_phone      text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_customer public.customers%rowtype;
begin
  if auth.uid() is null then
    raise exception 'A session is required to claim a customer record'
      using errcode = 'MN005';
  end if;

  select * into v_customer from public.customers where phone = p_phone;

  if not found then
    insert into public.customers (first_name, last_name, phone)
    values (trim(p_first_name), nullif(trim(coalesce(p_last_name, '')), ''), p_phone)
    returning * into v_customer;
  else
    if lower(trim(v_customer.first_name)) is distinct from lower(trim(p_first_name)) then
      raise exception 'The name does not match the record held for this number'
        using errcode = 'MN005';
    end if;

    -- A returning customer whose record was archived comes back rather than
    -- being duplicated; the phone number is unique for exactly this reason.
    if v_customer.deleted_at is not null then
      update public.customers
        set deleted_at = null, updated_at = now()
        where id = v_customer.id
        returning * into v_customer;
    end if;
  end if;

  insert into public.customer_devices (auth_user_id, customer_id)
  values (auth.uid(), v_customer.id)
  on conflict (auth_user_id) do update set customer_id = excluded.customer_id;

  return v_customer.id;
end;
$$;

revoke all on function public.claim_customer(text, text, text) from public, anon;
grant execute on function public.claim_customer(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- book_appointment(): the whole booking, in one transaction
-- ---------------------------------------------------------------------------
-- A booking is two rows — the appointment and the treatment chosen — and they
-- must not be able to exist apart. Doing it from the client would mean two
-- round trips with a window between them where a booking has no treatment and
-- no way to acquire one, so it happens here instead.
--
-- It also claims the customer, which is the same "find them or create them"
-- the profile screen does. That makes the whole of booking a single call:
-- identity, appointment and treatment together, or none of it.
--
-- Definer rights, so it can reach customers and appointment_services without
-- those tables needing client-facing write policies. It does not bypass the
-- rules: every trigger on appointments still fires, so MN001-MN004 apply
-- exactly as they would to a direct insert.

create or replace function public.book_appointment(
  p_first_name text,
  p_last_name  text,
  p_phone      text,
  p_slot_date  date,
  p_slot_hour  smallint,
  p_service_id text default null
)
returns public.appointments
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_customer_id uuid;
  v_appointment public.appointments%rowtype;
  v_service     public.services%rowtype;
begin
  v_customer_id := public.claim_customer(p_first_name, p_last_name, p_phone);

  insert into public.appointments
    (customer_id, slot_date, slot_hour, first_name, last_name, phone)
  values
    (v_customer_id, p_slot_date, p_slot_hour,
     trim(p_first_name), nullif(trim(coalesce(p_last_name, '')), ''), p_phone)
  returning * into v_appointment;

  if p_service_id is not null then
    select * into v_service
    from public.services
    where id = p_service_id and kind = 'main'
      and is_active and deleted_at is null;

    if not found then
      raise exception 'No such treatment: %', p_service_id
        using errcode = 'MN006';
    end if;

    insert into public.appointment_services
      (appointment_id, service_id, kind, amount)
    values
      (v_appointment.id, v_service.id, 'main', v_service.price_min);
  end if;

  return v_appointment;
end;
$$;

revoke all on function public.book_appointment(text, text, text, date, smallint, text) from public, anon;
grant execute on function public.book_appointment(text, text, text, date, smallint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- set_appointment_service(): change the treatment on an existing booking
-- ---------------------------------------------------------------------------
-- Swapping a treatment means retiring one line and adding another, which is
-- two writes for what the customer experiences as one choice. Same reasoning
-- as above; same guarantee.
--
-- Only the treatment. Add-ons are the salon's to record, and staff edit them
-- through the table directly.

create or replace function public.set_appointment_service(
  p_appointment_id uuid,
  p_service_id     text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_appointment public.appointments%rowtype;
  v_service     public.services%rowtype;
begin
  select * into v_appointment
  from public.appointments
  where id = p_appointment_id and deleted_at is null;

  if not found then
    raise exception 'No such appointment' using errcode = 'MN006';
  end if;

  -- Staff may change any booking; a customer only their own, and never one the
  -- salon entered on their behalf. Same rule as the update policy.
  if not coalesce(public.is_admin(), false) then
    if v_appointment.customer_id is distinct from public.current_customer_id()
       or v_appointment.created_by_admin then
      raise exception 'No such appointment' using errcode = 'MN006';
    end if;
  end if;

  update public.appointment_services
    set deleted_at = now()
    where appointment_id = p_appointment_id
      and kind = 'main'
      and deleted_at is null;

  if p_service_id is not null then
    select * into v_service
    from public.services
    where id = p_service_id and kind = 'main'
      and is_active and deleted_at is null;

    if not found then
      raise exception 'No such treatment: %', p_service_id
        using errcode = 'MN006';
    end if;

    insert into public.appointment_services
      (appointment_id, service_id, kind, amount)
    values (p_appointment_id, v_service.id, 'main', v_service.price_min);
  end if;
end;
$$;

revoke all on function public.set_appointment_service(uuid, text) from public, anon;
grant execute on function public.set_appointment_service(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- booked_slots(): which slots are taken, without saying by whom
-- ---------------------------------------------------------------------------
-- The grid has to work before the customer has any identity at all, so this is
-- granted to anon as well. It is safe to: it returns slot keys and nothing
-- else, so an unauthenticated caller learns exactly what somebody asking "are
-- you free at four?" learns.

create or replace function public.booked_slots(from_date date, to_date date)
returns table (slot_date date, slot_hour smallint)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select a.slot_date, a.slot_hour
  from public.appointments a
  where a.status in ('confirmed', 'completed')
    and a.deleted_at is null
    and a.slot_date >= from_date
    and a.slot_date <= to_date;
$$;

comment on function public.booked_slots(date, date) is
  'Taken slots in a date range. Returns slot keys only, never customer data.';

revoke all on function public.booked_slots(date, date) from public;
grant execute on function public.booked_slots(date, date) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- closed_days(): Sundays and declared closures, as dates
-- ---------------------------------------------------------------------------
-- So the calendar can grey a day out before anyone taps it, instead of letting
-- them pick a day and then refusing. Same reasoning as booked_slots: no
-- personal data, granted to anon.

create or replace function public.closed_days(from_date date, to_date date)
returns table (day date)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select d::date
  from generate_series(from_date, to_date, interval '1 day') as d
  where extract(isodow from d) = 7
     or exists (
       select 1 from public.salon_closures c
       where c.deleted_at is null
         and d::date between c.start_date and c.end_date
     );
$$;

comment on function public.closed_days(date, date) is
  'Days the salon is shut: every Sunday, plus any declared closure.';

revoke all on function public.closed_days(date, date) from public;
grant execute on function public.closed_days(date, date) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- touch_updated_at()
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

-- ===========================================================================
-- Rules, as triggers
-- ===========================================================================
-- Each rule raises its own SQLSTATE so the app can tell the customer exactly
-- which one they hit. PostgREST passes the code through in the error body and
-- maps anything it does not recognise to HTTP 400, which is the same status a
-- constraint violation produced before.
--
--   MN001  the slot has already started
--   MN002  the 21-day booking window
--   MN003  the salon is closed that day
--   MN004  too late to cancel
--   MN005  name does not match the number (raised by claim_customer)
--   MN006  asked for something that is not there (unknown treatment or
--          appointment) — a client bug rather than a rule, but named so it
--          does not masquerade as one

-- ---------------------------------------------------------------------------
-- Stamp who created the row
-- ---------------------------------------------------------------------------
-- Before anything else, and never from client input: created_by_admin decides
-- whether the booking-window and closed-day rules apply, so a customer able to
-- set it could book as often as they liked.

create or replace function public.stamp_appointment_origin()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.created_by       := auth.uid();
  new.created_by_admin := coalesce(public.is_admin(), false);
  return new;
end;
$$;

create trigger appointments_stamp_origin
  before insert on public.appointments
  for each row execute function public.stamp_appointment_origin();

-- ---------------------------------------------------------------------------
-- MN001 — no bookings in the past
-- ---------------------------------------------------------------------------
-- The client hides past slots, but a device with a wrong clock, or a direct
-- API call, must not be able to book yesterday. On UPDATE too, because
-- customers may move an appointment and must not move it backwards.

create or replace function public.reject_past_appointments()
returns trigger
language plpgsql
as $$
declare
  salon_now timestamp := (now() at time zone 'Europe/Istanbul');
begin
  if new.status in ('confirmed', 'completed')
     and new.deleted_at is null
     and (tg_op = 'INSERT'
          or new.slot_date is distinct from old.slot_date
          or new.slot_hour is distinct from old.slot_hour)
     and (new.slot_date + make_interval(hours => new.slot_hour)) <= salon_now then
    raise exception 'Cannot book a slot in the past'
      using errcode = 'MN001';
  end if;
  return new;
end;
$$;

create trigger appointments_reject_past
  before insert or update on public.appointments
  for each row execute function public.reject_past_appointments();

-- ---------------------------------------------------------------------------
-- MN002 — one visit per 21 days
-- ---------------------------------------------------------------------------
-- Symmetric: two live appointments for the same person may not sit within 21
-- days of each other, whichever was booked first. The rule exists so that a
-- customer comes roughly once every three weeks, and that reading does not
-- care which direction the second booking lies in.
--
-- Only appointments that count as having happened hold the window:
--   · confirmed → the slot is held, so it counts
--   · completed → they came, so it counts
--   · cancelled → freed, does not count
--   · no_show   → they did not come and received nothing, does not count
--
-- That last one has a consequence worth stating plainly: marking somebody a
-- no-show is what releases them to book again. It is not only a label for the
-- statistics page.
--
-- Staff are exempt. The row being changed is excluded from its own check,
-- otherwise nobody could ever reschedule.

create or replace function public.enforce_booking_window()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  window_days constant integer := 21;
  clash date;
begin
  if new.created_by_admin
     or new.deleted_at is not null
     or new.status not in ('confirmed', 'completed') then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.slot_date = old.slot_date
     and new.status = old.status
     and new.customer_id = old.customer_id then
    return new;
  end if;

  select a.slot_date into clash
  from public.appointments a
  where a.customer_id = new.customer_id
    and a.id <> new.id
    and a.deleted_at is null
    and a.status in ('confirmed', 'completed')
    and abs(a.slot_date - new.slot_date) < window_days
  order by a.slot_date
  limit 1;

  if found then
    raise exception
      'Only one appointment per % days; this customer already has one on %',
      window_days, clash
      using errcode = 'MN002';
  end if;

  return new;
end;
$$;

create trigger appointments_enforce_window
  before insert or update on public.appointments
  for each row execute function public.enforce_booking_window();

-- ---------------------------------------------------------------------------
-- MN003 — the salon is closed
-- ---------------------------------------------------------------------------
-- Sunday is a standing closure. Declared closures come from salon_closures.
-- Staff are exempt from both: the salon may take a regular on a Sunday, and
-- the person declaring a holiday is the same person who might need to book
-- inside it.

create or replace function public.reject_closed_days()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.created_by_admin
     or new.deleted_at is not null
     or new.status not in ('confirmed', 'completed') then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.slot_date = old.slot_date then
    return new;
  end if;

  if extract(isodow from new.slot_date) = 7 then
    raise exception 'The salon is closed on Sundays'
      using errcode = 'MN003';
  end if;

  if exists (
    select 1 from public.salon_closures c
    where c.deleted_at is null
      and new.slot_date between c.start_date and c.end_date
  ) then
    raise exception 'The salon is closed on %', new.slot_date
      using errcode = 'MN003';
  end if;

  return new;
end;
$$;

create trigger appointments_reject_closed
  before insert or update on public.appointments
  for each row execute function public.reject_closed_days();

-- ---------------------------------------------------------------------------
-- MN004 — too late to cancel
-- ---------------------------------------------------------------------------
-- A customer may call off a booking until an hour before it starts. After
-- that the slot is theirs to waste, and staff decide what it becomes — a
-- cancellation, or a no-show.
--
-- The exemption is checked against who is acting *now*, not who created the
-- row: staff cancelling a week-old booking on the customer's behalf is exactly
-- the case this must allow.

create or replace function public.enforce_cancel_deadline()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  salon_now timestamp := (now() at time zone 'Europe/Istanbul');
  starts_at timestamp;
begin
  if new.status <> 'cancelled' or old.status = 'cancelled' then
    return new;
  end if;

  if coalesce(public.is_admin(), false) then
    return new;
  end if;

  starts_at := old.slot_date + make_interval(hours => old.slot_hour);

  if starts_at - interval '1 hour' <= salon_now then
    raise exception 'An appointment can only be cancelled up to an hour before it starts'
      using errcode = 'MN004';
  end if;

  return new;
end;
$$;

create trigger appointments_enforce_cancel_deadline
  before update on public.appointments
  for each row execute function public.enforce_cancel_deadline();

-- ---------------------------------------------------------------------------
-- updated_at upkeep
-- ---------------------------------------------------------------------------

create trigger customers_touch_updated_at
  before update on public.customers
  for each row execute function public.touch_updated_at();

create trigger appointments_touch_updated_at
  before update on public.appointments
  for each row execute function public.touch_updated_at();

create trigger services_touch_updated_at
  before update on public.services
  for each row execute function public.touch_updated_at();

-- ===========================================================================
-- Row level security
-- ===========================================================================
-- Customers reach their own row and nothing else; staff reach everything.
-- There is no DELETE policy anywhere, on any table, on purpose: removal is
-- always `deleted_at`, so nothing the salon has ever recorded can be lost by
-- an app-side mistake.

alter table public.customers            enable row level security;
alter table public.customer_devices     enable row level security;
alter table public.services             enable row level security;
alter table public.appointments         enable row level security;
alter table public.appointment_services enable row level security;
alter table public.salon_closures       enable row level security;
alter table public.admins               enable row level security;

-- --- admins ----------------------------------------------------------------
-- A staff member may read their own row, so the app can answer "am I staff?".
-- The table is not enumerable and has no write policy at all: the roster is
-- managed from the SQL editor, never from an app.

create policy admins_select_self on public.admins
  for select to authenticated using (auth.uid() = id);

-- --- customers -------------------------------------------------------------
-- No customer INSERT policy: records are created only through
-- claim_customer(), which is where the name+phone match lives.

create policy customers_select_own on public.customers
  for select to authenticated
  using (id = public.current_customer_id() and deleted_at is null);

create policy customers_update_own on public.customers
  for update to authenticated
  using (id = public.current_customer_id() and deleted_at is null)
  with check (id = public.current_customer_id() and deleted_at is null);

create policy customers_select_admin on public.customers
  for select to authenticated using (public.is_admin());

create policy customers_insert_admin on public.customers
  for insert to authenticated with check (public.is_admin());

create policy customers_update_admin on public.customers
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- --- customer_devices ------------------------------------------------------
-- Read-only from the app; claim_customer() is the only writer.

create policy customer_devices_select_own on public.customer_devices
  for select to authenticated using (auth_user_id = auth.uid());

create policy customer_devices_select_admin on public.customer_devices
  for select to authenticated using (public.is_admin());

-- --- services --------------------------------------------------------------
-- Readable without a session: the price list is public information, and the
-- booking screen shows it before anyone has identified themselves.

create policy services_select_active on public.services
  for select to anon, authenticated
  using (is_active and deleted_at is null);

create policy services_select_admin on public.services
  for select to authenticated using (public.is_admin());

create policy services_insert_admin on public.services
  for insert to authenticated with check (public.is_admin());

create policy services_update_admin on public.services
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- --- appointments ----------------------------------------------------------
-- A customer sees a booking of theirs when it is still ahead of them, or when
-- this very device made it. The first half is what limits the damage if
-- somebody claims a number that is not theirs — they inherit no history. The
-- second half is what stops that limit from punishing the genuine owner, whose
-- own past bookings stay visible on the device that made them.

create policy appointments_select_own on public.appointments
  for select to authenticated
  using (
    customer_id = public.current_customer_id()
    and deleted_at is null
    and (slot_date >= current_date or created_by = auth.uid())
  );

create policy appointments_insert_own on public.appointments
  for insert to authenticated
  with check (customer_id = public.current_customer_id() and deleted_at is null);

-- Staff-created bookings are not the device's to change: whoever typed a phone
-- number into the app did not necessarily make that booking. Rescheduling or
-- cancelling one means calling the salon.
create policy appointments_update_own on public.appointments
  for update to authenticated
  using (
    customer_id = public.current_customer_id()
    and deleted_at is null
    and not created_by_admin
  )
  with check (
    customer_id = public.current_customer_id()
    and not created_by_admin
  );

create policy appointments_select_admin on public.appointments
  for select to authenticated using (public.is_admin());

create policy appointments_insert_admin on public.appointments
  for insert to authenticated with check (public.is_admin());

create policy appointments_update_admin on public.appointments
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- --- appointment_services --------------------------------------------------
-- Customers read their line items and never write them: book_appointment() and
-- set_appointment_service() are the only paths in, so a treatment and its
-- price always arrive together and always come from the catalogue.

create policy appointment_services_select_own on public.appointment_services
  for select to authenticated
  using (deleted_at is null and exists (
    select 1 from public.appointments a
    where a.id = appointment_id
      and a.customer_id = public.current_customer_id()
      and a.deleted_at is null
  ));

-- Retired lines stay in the table but out of every read: the app never has a
-- reason to show one, and filtering here means neither client has to remember
-- to. What was removed is still recoverable in SQL if it is ever asked for.
create policy appointment_services_select_admin on public.appointment_services
  for select to authenticated
  using (public.is_admin() and deleted_at is null);

create policy appointment_services_insert_admin on public.appointment_services
  for insert to authenticated with check (public.is_admin());

create policy appointment_services_update_admin on public.appointment_services
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Staff correcting what was done take a line off by setting deleted_at, which
-- the update policy above already allows. No DELETE policy — see the note at
-- the top of this section.

-- --- salon_closures --------------------------------------------------------
-- Readable by everyone, including before sign-in, so the calendar can grey out
-- a holiday instead of refusing a tap.

create policy salon_closures_select_all on public.salon_closures
  for select to anon, authenticated using (deleted_at is null);

create policy salon_closures_insert_admin on public.salon_closures
  for insert to authenticated with check (public.is_admin());

create policy salon_closures_update_admin on public.salon_closures
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
