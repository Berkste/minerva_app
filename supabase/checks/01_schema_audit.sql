-- Minerva Nail Art — schema audit.
--
-- Read-only. Paste the whole file into the Supabase SQL editor and run it; it
-- returns one row per check, failures first. Nothing here writes anything.
--
-- What it answers: does this project's live schema actually match what the app
-- expects — tables, columns, the uniqueness index the whole design rests on,
-- the triggers that carry the salon's rules, functions, grants and RLS.
-- Written against `20260921120000_schema.sql` + `20260921120100_catalogue.sql`.
--
-- Severity:
--   FAIL   the app will misbehave, or a rule is not actually in force
--   WARN   works, but is not what the migrations describe — look at it
--   INFO   printed for eyeballing, never a pass/fail
--
-- This file reads the catalogue only, never customer rows, so it runs and
-- reports even when something is missing. Data-side invariants live in
-- `02_data_audit.sql`.

with

-- ---------------------------------------------------------------------------
-- Expectations
-- ---------------------------------------------------------------------------

expected_tables(tbl) as (values
  ('customers'), ('customer_devices'), ('services'),
  ('appointments'), ('appointment_services'), ('salon_closures'), ('admins')
),

expected_columns(tbl, col, typ, nullable) as (values
  ('customers',            'id',               'uuid',                     'NO'),
  ('customers',            'first_name',       'text',                     'NO'),
  -- The phase 2 decision: only a first name and a phone are required.
  ('customers',            'last_name',        'text',                     'YES'),
  ('customers',            'phone',            'text',                     'NO'),
  ('customers',            'created_by_admin', 'boolean',                  'NO'),
  ('customers',            'deleted_at',       'timestamp with time zone', 'YES'),

  ('customer_devices',     'auth_user_id',     'uuid',                     'NO'),
  ('customer_devices',     'customer_id',      'uuid',                     'NO'),

  ('services',             'id',               'text',                     'NO'),
  ('services',             'kind',             'USER-DEFINED',             'NO'),
  ('services',             'name_tr',          'text',                     'NO'),
  ('services',             'name_en',          'text',                     'NO'),
  ('services',             'price_min',        'numeric',                  'NO'),
  ('services',             'price_max',        'numeric',                  'YES'),
  ('services',             'is_active',        'boolean',                  'NO'),
  ('services',             'deleted_at',       'timestamp with time zone', 'YES'),

  ('appointments',         'id',               'uuid',                     'NO'),
  ('appointments',         'customer_id',      'uuid',                     'NO'),
  ('appointments',         'slot_date',        'date',                     'NO'),
  ('appointments',         'slot_hour',        'smallint',                 'NO'),
  ('appointments',         'first_name',       'text',                     'NO'),
  ('appointments',         'last_name',        'text',                     'YES'),
  ('appointments',         'phone',            'text',                     'NO'),
  ('appointments',         'status',           'USER-DEFINED',             'NO'),
  ('appointments',         'created_by',       'uuid',                     'YES'),
  ('appointments',         'created_by_admin', 'boolean',                  'NO'),
  ('appointments',         'cancelled_by',     'USER-DEFINED',             'YES'),
  ('appointments',         'cancelled_at',     'timestamp with time zone', 'YES'),
  ('appointments',         'deleted_at',       'timestamp with time zone', 'YES'),

  ('appointment_services', 'appointment_id',   'uuid',                     'NO'),
  ('appointment_services', 'service_id',       'text',                     'NO'),
  ('appointment_services', 'kind',             'USER-DEFINED',             'NO'),
  ('appointment_services', 'amount',           'numeric',                  'NO'),
  ('appointment_services', 'deleted_at',       'timestamp with time zone', 'YES'),

  ('salon_closures',       'start_date',       'date',                     'NO'),
  ('salon_closures',       'end_date',         'date',                     'NO'),
  ('salon_closures',       'deleted_at',       'timestamp with time zone', 'YES'),

  ('admins',               'id',               'uuid',                     'NO'),
  ('admins',               'created_at',       'timestamp with time zone', 'NO')
),

expected_policies(tbl, pol, cmd) as (values
  ('admins',               'admins_select_self',                'SELECT'),

  ('customers',            'customers_select_own',              'SELECT'),
  ('customers',            'customers_update_own',              'UPDATE'),
  ('customers',            'customers_select_admin',            'SELECT'),
  ('customers',            'customers_insert_admin',            'INSERT'),
  ('customers',            'customers_update_admin',            'UPDATE'),

  ('customer_devices',     'customer_devices_select_own',       'SELECT'),
  ('customer_devices',     'customer_devices_select_admin',     'SELECT'),

  ('services',             'services_select_active',            'SELECT'),
  ('services',             'services_select_admin',             'SELECT'),
  ('services',             'services_insert_admin',             'INSERT'),
  ('services',             'services_update_admin',             'UPDATE'),

  ('appointments',         'appointments_select_own',           'SELECT'),
  ('appointments',         'appointments_insert_own',           'INSERT'),
  ('appointments',         'appointments_update_own',           'UPDATE'),
  ('appointments',         'appointments_select_admin',         'SELECT'),
  ('appointments',         'appointments_insert_admin',         'INSERT'),
  ('appointments',         'appointments_update_admin',         'UPDATE'),

  ('appointment_services', 'appointment_services_select_own',   'SELECT'),
  ('appointment_services', 'appointment_services_insert_own',   'INSERT'),
  ('appointment_services', 'appointment_services_select_admin', 'SELECT'),
  ('appointment_services', 'appointment_services_insert_admin', 'INSERT'),
  ('appointment_services', 'appointment_services_update_admin', 'UPDATE'),

  ('salon_closures',       'salon_closures_select_all',         'SELECT'),
  ('salon_closures',       'salon_closures_insert_admin',       'INSERT'),
  ('salon_closures',       'salon_closures_update_admin',       'UPDATE')
),

-- Each rule lives in its own function and raises its own SQLSTATE, so the app
-- can tell the customer which rule they hit. If a body stops carrying its
-- code, the rule still fires but the customer gets a generic error instead of
-- an explanation.
expected_rule_codes(fn, code, rule) as (values
  ('public.reject_past_appointments()',      'MN001', 'no bookings in the past'),
  ('public.enforce_booking_window()',        'MN002', 'one visit per 21 days'),
  ('public.reject_closed_days()',            'MN003', 'Sundays and declared closures'),
  ('public.enforce_cancel_deadline()',       'MN004', 'cancel up to an hour before'),
  ('public.claim_customer(text,text,text)',  'MN005', 'name must match the number')
),

-- ---------------------------------------------------------------------------
-- 1. Objects exist
-- ---------------------------------------------------------------------------

c_tables as (
  select case when to_regclass('public.' || tbl) is not null then 'OK' else 'FAIL' end as status,
         '1. objects' as area,
         'table public.' || tbl as check_name,
         coalesce(to_regclass('public.' || tbl)::text, 'MISSING') as detail
  from expected_tables
),

c_enums as (
  select case when a.actual = e.want then 'OK' else 'FAIL' end,
         '1. objects',
         'enum public.' || e.nm,
         coalesce(a.actual, 'MISSING') || '  (expected: ' || e.want || ')'
  from (values
    ('appointment_status', 'confirmed,cancelled,completed,no_show'),
    ('service_kind',       'main,extra'),
    ('actor',              'customer,admin')
  ) as e(nm, want)
  left join lateral (
    select string_agg(en.enumlabel, ',' order by en.enumsortorder) as actual
    from pg_type ty
    join pg_enum en on en.enumtypid = ty.oid
    join pg_namespace n on n.oid = ty.typnamespace
    where n.nspname = 'public' and ty.typname = e.nm
  ) a on true
),

-- ---------------------------------------------------------------------------
-- 2. Columns
-- ---------------------------------------------------------------------------

actual_columns as (
  select table_name as tbl, column_name as col, data_type as typ, is_nullable as nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name in (select tbl from expected_tables)
),

c_columns as (
  select case
           when a.col is null then 'FAIL'
           when a.typ is distinct from e.typ or a.nullable is distinct from e.nullable then 'FAIL'
           else 'OK'
         end,
         '2. columns',
         e.tbl || '.' || e.col,
         case
           when a.col is null then 'MISSING (expected ' || e.typ || ', nullable=' || e.nullable || ')'
           else a.typ || ', nullable=' || a.nullable ||
                '  (expected ' || e.typ || ', nullable=' || e.nullable || ')'
         end
  from expected_columns e
  left join actual_columns a on a.tbl = e.tbl and a.col = e.col
),

-- ---------------------------------------------------------------------------
-- 3. The guarantees that rest on an index
-- ---------------------------------------------------------------------------

c_indexes as (
  select case
           when x.d is null then 'FAIL'
           when x.d ilike '%create unique index%' and x.d ilike want.shape then 'OK'
           else 'FAIL'
         end,
         '3. uniqueness',
         want.idx,
         coalesce(x.d, 'MISSING — ' || want.consequence)
  from (values
    ('appointments_one_active_per_slot',
     '%(slot_date, slot_hour)%confirmed%completed%deleted_at is null%',
     'two people could hold the same slot'),
    ('appointment_one_main_service',
     '%(appointment_id)%main%deleted_at is null%',
     'one appointment could hold two treatments'),
    ('customers_phone_key',
     '%(phone)%',
     'the same person could exist twice')
  ) as want(idx, shape, consequence)
  left join lateral (
    select pg_get_indexdef(i.indexrelid) as d
    from pg_index i join pg_class c on c.oid = i.indexrelid
    where c.relname = want.idx
  ) x on true
),

-- ---------------------------------------------------------------------------
-- 4. Constraints
-- ---------------------------------------------------------------------------

c_fk_cascade as (
  select case when pc.confdeltype = 'c' then 'OK' else 'FAIL' end,
         '4. constraints',
         want.label || ' on delete cascade',
         coalesce('on delete = ' || pc.confdeltype, 'MISSING') || '  (expected c = cascade)'
  from (values
    ('customer_devices',     'customer_devices_auth_user_id_fkey',       'customer_devices → auth.users'),
    ('customer_devices',     'customer_devices_customer_id_fkey',        'customer_devices → customers'),
    ('appointments',         'appointments_customer_id_fkey',            'appointments → customers'),
    ('appointment_services', 'appointment_services_appointment_id_fkey', 'appointment_services → appointments'),
    ('admins',               'admins_id_fkey',                           'admins → auth.users')
  ) as want(tbl, conname, label)
  left join pg_constraint pc
    on pc.conname = want.conname and pc.conrelid = to_regclass('public.' || want.tbl)
),

c_composite_fk as (
  select case when x.def is null then 'FAIL' else 'OK' end,
         '4. constraints',
         'appointment_services (service_id, kind) → services',
         coalesce(x.def, 'MISSING — a line item''s kind could disagree with the catalogue')
  from (select 1) _
  left join lateral (
    select pg_get_constraintdef(oid) as def
    from pg_constraint
    where conrelid = to_regclass('public.appointment_services')
      and contype = 'f'
      and pg_get_constraintdef(oid) ilike '%(service_id, kind)%'
    limit 1
  ) x on true
),

c_named_checks as (
  select case when x.def is null then 'FAIL' else 'OK' end,
         '4. constraints',
         want.tbl || '.' || want.conname,
         coalesce(x.def, 'MISSING')
  from (values
    ('appointments',   'cancelled_fields_match_status'),
    ('salon_closures', 'closure_range_valid')
  ) as want(tbl, conname)
  left join lateral (
    select pg_get_constraintdef(oid) as def
    from pg_constraint
    where conrelid = to_regclass('public.' || want.tbl) and conname = want.conname
  ) x on true
),

c_constraint_inventory as (
  select 'INFO', '4. constraints',
         cl.relname || '.' || pc.conname,
         pg_get_constraintdef(pc.oid)
  from pg_constraint pc
  join pg_class cl on cl.oid = pc.conrelid
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public'
    and cl.relname in (select tbl from expected_tables)
    and pc.contype in ('c', 'f', 'p', 'u')
),

-- ---------------------------------------------------------------------------
-- 5. Triggers — a rule only exists if its trigger is attached
-- ---------------------------------------------------------------------------

c_triggers as (
  select case when x.d is null then 'FAIL'
              when want.needs_update and x.d not ilike '%update%' then 'FAIL'
              else 'OK' end,
         '5. triggers',
         want.trg,
         coalesce(x.d, 'MISSING — the rule it carries is not in force')
  from (values
    ('appointments_stamp_origin',            false),
    ('appointments_reject_past',             true),
    ('appointments_enforce_window',          true),
    ('appointments_reject_closed',           true),
    ('appointments_enforce_cancel_deadline', true),
    ('customers_touch_updated_at',           false),
    ('appointments_touch_updated_at',        false),
    ('services_touch_updated_at',            false)
  ) as want(trg, needs_update)
  left join lateral (
    select pg_get_triggerdef(t.oid) as d
    from pg_trigger t
    where not t.tgisinternal and t.tgname = want.trg
  ) x on true
),

-- ---------------------------------------------------------------------------
-- 6. Functions
-- ---------------------------------------------------------------------------

c_functions as (
  select case
           when p.oid is null then 'FAIL'
           when p.prosecdef is distinct from want.secdef then 'FAIL'
           when want.secdef and coalesce(array_to_string(p.proconfig, ','), '') not like '%search_path%' then 'FAIL'
           else 'OK'
         end,
         '6. functions',
         want.sig,
         case
           when p.oid is null then 'MISSING'
           else 'security definer=' || p.prosecdef ||
                ', config=' || coalesce(array_to_string(p.proconfig, ' '), '(none)') ||
                '  (expected definer=' || want.secdef ||
                case when want.secdef then ', search_path pinned' else '' end || ')'
         end
  from (values
    ('public.is_admin()',                      true),
    ('public.current_customer_id()',           true),
    ('public.claim_customer(text,text,text)',  true),
    ('public.booked_slots(date,date)',         true),
    ('public.closed_days(date,date)',          true),
    ('public.stamp_appointment_origin()',      true),
    ('public.enforce_booking_window()',        true),
    ('public.reject_closed_days()',            true),
    ('public.enforce_cancel_deadline()',       true),
    ('public.reject_past_appointments()',      false),
    ('public.touch_updated_at()',              false)
  ) as want(sig, secdef)
  left join pg_proc p on p.oid = to_regprocedure(want.sig)
),

c_rule_codes as (
  select case
           when p.oid is null then 'FAIL'
           when pg_get_functiondef(p.oid) like '%' || e.code || '%' then 'OK'
           else 'FAIL'
         end,
         '6. functions',
         e.code || ' — ' || e.rule,
         case
           when p.oid is null then 'MISSING function ' || e.fn
           when pg_get_functiondef(p.oid) like '%' || e.code || '%'
             then 'raises ' || e.code || '  (expected ' || e.code || ')'
           else 'does NOT raise ' || e.code || ' — the app cannot name this rule'
         end
  from expected_rule_codes e
  left join pg_proc p on p.oid = to_regprocedure(e.fn)
),

-- ---------------------------------------------------------------------------
-- 7. Grants
-- ---------------------------------------------------------------------------
-- booked_slots and closed_days are callable without a session: the calendar
-- has to work before anyone identifies themselves, and neither returns
-- personal data. Everything else must require one.

c_grants as (
  select case
           when to_regprocedure(want.sig) is null then 'FAIL'
           when has_function_privilege(want.role_name, to_regprocedure(want.sig), 'EXECUTE') = want.should
             then 'OK' else 'FAIL'
         end,
         '7. grants',
         want.role_name || ' may execute ' || want.sig,
         case
           when to_regprocedure(want.sig) is null then 'function missing'
           else 'actual=' || has_function_privilege(want.role_name, to_regprocedure(want.sig), 'EXECUTE') ||
                '  (expected ' || want.should || ')'
         end
  from (values
    ('anon',          'public.booked_slots(date,date)',        true),
    ('authenticated', 'public.booked_slots(date,date)',        true),
    ('anon',          'public.closed_days(date,date)',         true),
    ('authenticated', 'public.closed_days(date,date)',         true),
    ('anon',          'public.is_admin()',                     false),
    ('authenticated', 'public.is_admin()',                     true),
    ('anon',          'public.current_customer_id()',          false),
    ('authenticated', 'public.current_customer_id()',          true),
    ('anon',          'public.claim_customer(text,text,text)', false),
    ('authenticated', 'public.claim_customer(text,text,text)', true)
  ) as want(role_name, sig, should)
),

-- ---------------------------------------------------------------------------
-- 8. Row level security
-- ---------------------------------------------------------------------------

c_rls_enabled as (
  select case when cl.relrowsecurity then 'OK' else 'FAIL' end,
         '8. RLS',
         'row level security on public.' || e.tbl,
         case when cl.oid is null then 'table missing'
              when cl.relrowsecurity then 'enabled'
              else 'DISABLED — every row is readable by anyone' end
  from expected_tables e
  left join pg_class cl on cl.oid = to_regclass('public.' || e.tbl)
),

c_rls_all_public_tables as (
  select case when count(*) = 0 then 'OK' else 'FAIL' end,
         '8. RLS',
         'no public table left without RLS',
         coalesce(string_agg(cl.relname, ', '), 'clean')
  from pg_class cl
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public' and cl.relkind = 'r' and not cl.relrowsecurity
),

c_policies_missing as (
  select case when p.policyname is null then 'FAIL'
              when upper(p.cmd) is distinct from e.cmd then 'FAIL'
              else 'OK' end,
         '8. RLS',
         'policy ' || e.pol,
         case when p.policyname is null then 'MISSING'
              else p.cmd || ' | using: ' || coalesce(p.qual, '—') ||
                   ' | with check: ' || coalesce(p.with_check, '—') end
  from expected_policies e
  left join pg_policies p
    on p.schemaname = 'public' and p.tablename = e.tbl and p.policyname = e.pol
),

c_policies_extra as (
  select 'WARN', '8. RLS',
         'unexpected policy ' || p.policyname,
         p.tablename || ' | ' || p.cmd || ' | using: ' || coalesce(p.qual, '—')
  from pg_policies p
  left join expected_policies e on e.tbl = p.tablename and e.pol = p.policyname
  where p.schemaname = 'public' and e.pol is null
),

-- The rule the whole soft-delete design rests on: nothing is ever removed, so
-- no table anywhere may carry a DELETE policy.
c_no_delete_policy as (
  select case when count(*) = 0 then 'OK' else 'FAIL' end,
         '8. RLS',
         'no DELETE policy anywhere (everything is soft-deleted)',
         coalesce(string_agg(tablename || '.' || policyname, ', '), 'clean')
  from pg_policies
  where schemaname = 'public' and upper(cmd) in ('DELETE', 'ALL')
),

c_admins_not_enumerable as (
  select case when count(*) = 1 then 'OK' else 'FAIL' end,
         '8. RLS',
         'admins table is not enumerable',
         coalesce(string_agg(policyname || ' (' || cmd || ')', ', '), 'no policy at all') ||
         '  (expected exactly admins_select_self (SELECT))'
  from pg_policies where schemaname = 'public' and tablename = 'admins'
),

-- A customer must never be able to claim their booking was made by staff:
-- that flag is what exempts a row from the 21-day window and the closed-day
-- rule. It is stamped by a trigger precisely so client input cannot reach it.
c_origin_stamped as (
  select case when x.attached then 'OK' else 'FAIL' end,
         '8. RLS',
         'created_by_admin is stamped, not accepted from the client',
         case when x.attached then 'appointments_stamp_origin is attached'
              else 'MISSING — a customer could exempt themselves from the 21-day rule' end
  from (
    select exists (
      select 1 from pg_trigger t
      join pg_proc p on p.oid = t.tgfoid
      where not t.tgisinternal
        and t.tgrelid = to_regclass('public.appointments')
        and p.proname = 'stamp_appointment_origin'
    ) as attached
  ) x
),

-- ---------------------------------------------------------------------------
-- 9. Nothing unexpected left lying around
-- ---------------------------------------------------------------------------

c_extra_tables as (
  select 'WARN', '9. leftovers',
         'unexpected table public.' || cl.relname,
         'not part of the schema — left over from an older migration?'
  from pg_class cl
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public' and cl.relkind = 'r'
    and cl.relname not in (select tbl from expected_tables)
),

c_extra_definers as (
  select 'WARN', '9. leftovers',
         'unexpected security definer function ' || p.proname,
         'definer functions bypass RLS — confirm this one is meant to exist'
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and format('public.%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
        not in (
          'public.is_admin()',
          'public.current_customer_id()',
          'public.claim_customer(text, text, text)',
          'public.booked_slots(date, date)',
          'public.closed_days(date, date)',
          'public.stamp_appointment_origin()',
          'public.enforce_booking_window()',
          'public.reject_closed_days()',
          'public.enforce_cancel_deadline()'
        )
),

all_checks(status, area, check_name, detail) as (
            select * from c_tables
  union all select * from c_enums
  union all select * from c_columns
  union all select * from c_indexes
  union all select * from c_fk_cascade
  union all select * from c_composite_fk
  union all select * from c_named_checks
  union all select * from c_constraint_inventory
  union all select * from c_triggers
  union all select * from c_functions
  union all select * from c_rule_codes
  union all select * from c_grants
  union all select * from c_rls_enabled
  union all select * from c_rls_all_public_tables
  union all select * from c_policies_missing
  union all select * from c_policies_extra
  union all select * from c_no_delete_policy
  union all select * from c_admins_not_enumerable
  union all select * from c_origin_stamped
  union all select * from c_extra_tables
  union all select * from c_extra_definers
)

select status, area, check_name, detail
from all_checks
order by
  case status when 'FAIL' then 1 when 'WARN' then 2 when 'OK' then 3 else 4 end,
  area,
  check_name;
