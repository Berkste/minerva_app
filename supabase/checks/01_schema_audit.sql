-- Minerva Nail Art — schema audit.
--
-- Read-only. Paste the whole file into the Supabase SQL editor and run it; it
-- returns one row per check, failures first. Nothing here writes anything.
--
-- What it answers: does this project's live schema actually match what the app
-- expects, object by object — tables, columns, constraints, the uniqueness
-- index the whole design rests on, triggers, functions, grants and RLS
-- policies. Written against `20260827120000_init.sql` +
-- `20260828120000_admin.sql`.
--
-- Severity:
--   FAIL   the app will misbehave, or a privacy rule is not in force
--   WARN   works, but is not what the migrations describe — look at it
--   INFO   printed for eyeballing, never a pass/fail
--
-- This file reads the catalogue only, never the tables themselves, so it runs
-- and reports even when something is missing. The data-side invariants — no
-- duplicate slots, what is actually stored — live in `02_data_audit.sql`.

with

-- ---------------------------------------------------------------------------
-- Expectations
-- ---------------------------------------------------------------------------

expected_columns(tbl, col, typ, nullable) as (values
  ('profiles',     'id',           'uuid',                        'NO'),
  ('profiles',     'first_name',   'text',                        'NO'),
  ('profiles',     'last_name',    'text',                        'NO'),
  ('profiles',     'phone',        'text',                        'NO'),
  ('profiles',     'created_at',   'timestamp with time zone',    'NO'),
  ('profiles',     'updated_at',   'timestamp with time zone',    'NO'),

  ('appointments', 'id',           'uuid',                        'NO'),
  ('appointments', 'user_id',      'uuid',                        'NO'),
  ('appointments', 'slot_date',    'date',                        'NO'),
  ('appointments', 'slot_hour',    'smallint',                    'NO'),
  ('appointments', 'service_id',   'text',                        'YES'),
  ('appointments', 'first_name',   'text',                        'NO'),
  ('appointments', 'last_name',    'text',                        'NO'),
  ('appointments', 'phone',        'text',                        'NO'),
  ('appointments', 'status',       'USER-DEFINED',                'NO'),
  ('appointments', 'created_at',   'timestamp with time zone',    'NO'),
  ('appointments', 'cancelled_at', 'timestamp with time zone',    'YES'),

  ('admins',       'id',           'uuid',                        'NO'),
  ('admins',       'created_at',   'timestamp with time zone',    'NO')
),

expected_policies(tbl, pol, cmd) as (values
  ('profiles',     'profiles_select_own',        'SELECT'),
  ('profiles',     'profiles_insert_own',        'INSERT'),
  ('profiles',     'profiles_update_own',        'UPDATE'),
  ('profiles',     'profiles_select_admin',      'SELECT'),

  ('appointments', 'appointments_select_own',    'SELECT'),
  ('appointments', 'appointments_insert_own',    'INSERT'),
  ('appointments', 'appointments_update_own',    'UPDATE'),
  ('appointments', 'appointments_select_admin',  'SELECT'),
  ('appointments', 'appointments_update_admin',  'UPDATE'),

  ('admins',       'admins_select_self',         'SELECT')
),

-- ---------------------------------------------------------------------------
-- 1. Objects exist
-- ---------------------------------------------------------------------------

c_objects as (
  select 'FAIL' as sev, '1. objects' as area,
         'table public.' || t as check_name,
         case when to_regclass('public.' || t) is not null then 'OK' else 'FAIL' end as status,
         coalesce(to_regclass('public.' || t)::text, 'MISSING') as detail
  from unnest(array['profiles', 'appointments', 'admins']) as t
),

c_enum as (
  select 'FAIL', '1. objects', 'enum public.appointment_status',
         case when coalesce((
           select string_agg(e.enumlabel, ',' order by e.enumsortorder)
           from pg_type ty join pg_enum e on e.enumtypid = ty.oid
           join pg_namespace n on n.oid = ty.typnamespace
           where n.nspname = 'public' and ty.typname = 'appointment_status'
         ), '') = 'confirmed,cancelled' then 'OK' else 'FAIL' end,
         coalesce((
           select string_agg(e.enumlabel, ',' order by e.enumsortorder)
           from pg_type ty join pg_enum e on e.enumtypid = ty.oid
           join pg_namespace n on n.oid = ty.typnamespace
           where n.nspname = 'public' and ty.typname = 'appointment_status'
         ), 'MISSING') || '  (expected: confirmed,cancelled)'
),

-- ---------------------------------------------------------------------------
-- 2. Columns — every column the app reads or writes, with type and nullability
-- ---------------------------------------------------------------------------

actual_columns as (
  select table_name as tbl, column_name as col, data_type as typ, is_nullable as nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name in ('profiles', 'appointments', 'admins')
),

c_columns_missing as (
  select 'FAIL', '2. columns', e.tbl || '.' || e.col,
         case
           when a.col is null then 'FAIL'
           when a.typ is distinct from e.typ or a.nullable is distinct from e.nullable then 'FAIL'
           else 'OK'
         end,
         case
           when a.col is null then 'MISSING (expected ' || e.typ || ', nullable=' || e.nullable || ')'
           else a.typ || ', nullable=' || a.nullable ||
                '  (expected ' || e.typ || ', nullable=' || e.nullable || ')'
         end
  from expected_columns e
  left join actual_columns a on a.tbl = e.tbl and a.col = e.col
),

c_columns_extra as (
  select 'WARN', '2. columns', a.tbl || '.' || a.col, 'WARN',
         'column exists here but not in the migrations — ' || a.typ
  from actual_columns a
  left join expected_columns e on e.tbl = a.tbl and e.col = a.col
  where e.col is null
),

-- ---------------------------------------------------------------------------
-- 3. The concurrency guard — the one thing the whole design rests on
-- ---------------------------------------------------------------------------

c_unique_index as (
  select 'FAIL', '3. uniqueness', 'appointments_one_confirmed_per_slot',
         case
           when idx.indexdef is null then 'FAIL'
           when idx.indexdef ilike '%create unique index%'
            and idx.indexdef ilike '%(slot_date, slot_hour)%'
            and idx.indexdef ilike '%where%status%confirmed%' then 'OK'
           else 'FAIL'
         end,
         coalesce(idx.indexdef, 'MISSING — double booking is possible without this')
  from (select 1) _
  left join lateral (
    select pg_get_indexdef(i.indexrelid) as indexdef
    from pg_index i
    join pg_class ic on ic.oid = i.indexrelid
    where ic.relname = 'appointments_one_confirmed_per_slot'
  ) idx on true
),

c_lookup_index as (
  select 'WARN', '3. uniqueness', 'appointments_user_slot_idx',
         case when to_regclass('public.appointments_user_slot_idx') is not null
              then 'OK' else 'WARN' end,
         coalesce((
           select pg_get_indexdef(i.indexrelid)
           from pg_index i join pg_class ic on ic.oid = i.indexrelid
           where ic.relname = 'appointments_user_slot_idx'
         ), 'missing — only a performance index, not a correctness one')
),

-- ---------------------------------------------------------------------------
-- 4. Constraints
-- ---------------------------------------------------------------------------

c_named_constraint as (
  select 'FAIL', '4. constraints', 'appointments.cancelled_at_matches_status',
         case when exists (
           select 1 from pg_constraint
           where conname = 'cancelled_at_matches_status'
             and conrelid = 'public.appointments'::regclass
         ) then 'OK' else 'FAIL' end,
         coalesce((
           select pg_get_constraintdef(oid) from pg_constraint
           where conname = 'cancelled_at_matches_status'
             and conrelid = 'public.appointments'::regclass
         ), 'MISSING — a row could be cancelled without a cancelled_at')
),

c_fk_cascade as (
  select 'FAIL', '4. constraints',
         rel.relname || ' → auth.users on delete cascade',
         case when con.confdeltype = 'c' then 'OK' else 'FAIL' end,
         'on delete = ' || con.confdeltype || '  (expected c = cascade)'
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_class frel on frel.oid = con.confrelid
  join pg_namespace fn on fn.oid = frel.relnamespace
  where con.contype = 'f'
    and rel.relname in ('profiles', 'appointments', 'admins')
    and fn.nspname = 'auth' and frel.relname = 'users'
),

c_constraint_inventory as (
  select 'INFO', '4. constraints',
         rel.relname || '.' || con.conname, 'INFO',
         pg_get_constraintdef(con.oid)
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace n on n.oid = rel.relnamespace
  where n.nspname = 'public'
    and rel.relname in ('profiles', 'appointments', 'admins')
    and con.contype in ('c', 'f', 'p')
),

-- ---------------------------------------------------------------------------
-- 5. Triggers
-- ---------------------------------------------------------------------------

c_triggers as (
  select 'FAIL', '5. triggers', want.name,
         case when tg.tgname is null then 'FAIL' else 'OK' end,
         coalesce(pg_get_triggerdef(tg.oid), 'MISSING')
  from (values
    ('appointments_reject_past',    'appointments'),
    ('profiles_touch_updated_at',   'profiles')
  ) as want(name, tbl)
  left join pg_trigger tg
    on tg.tgname = want.name
   and tg.tgrelid = ('public.' || want.tbl)::regclass
   and not tg.tgisinternal
),

-- ---------------------------------------------------------------------------
-- 6. Functions — existence, security definer, volatility, pinned search_path
-- ---------------------------------------------------------------------------

c_functions as (
  select 'FAIL', '6. functions', want.sig,
         case
           when p.oid is null then 'FAIL'
           when p.prosecdef is distinct from want.secdef then 'FAIL'
           when want.secdef and coalesce(array_to_string(p.proconfig, ','), '') not like '%search_path%' then 'FAIL'
           else 'OK'
         end,
         case
           when p.oid is null then 'MISSING'
           else 'security definer=' || p.prosecdef ||
                ', volatility=' || p.provolatile ||
                ', config=' || coalesce(array_to_string(p.proconfig, ' '), '(none)') ||
                '  (expected definer=' || want.secdef ||
                case when want.secdef then ', search_path pinned' else '' end || ')'
         end
  from (values
    ('public.booked_slots(date,date)',        true),
    ('public.is_admin()',                     true),
    ('public.reject_past_appointments()',     false),
    ('public.touch_updated_at()',             false)
  ) as want(sig, secdef)
  left join pg_proc p on p.oid = to_regprocedure(want.sig)
),

-- ---------------------------------------------------------------------------
-- 7. Function grants — anon must not be able to call the definer functions
-- ---------------------------------------------------------------------------

c_grants as (
  select 'FAIL', '7. grants', want.role_name || ' may execute ' || want.sig,
         case
           when to_regprocedure(want.sig) is null then 'FAIL'
           when has_function_privilege(want.role_name, to_regprocedure(want.sig), 'EXECUTE') = want.should
             then 'OK' else 'FAIL'
         end,
         case
           when to_regprocedure(want.sig) is null then 'function missing'
           else 'actual=' || has_function_privilege(want.role_name, to_regprocedure(want.sig), 'EXECUTE') ||
                '  (expected ' || want.should || ')'
         end
  from (values
    ('authenticated', 'public.booked_slots(date,date)', true),
    ('anon',          'public.booked_slots(date,date)', false),
    ('authenticated', 'public.is_admin()',              true),
    ('anon',          'public.is_admin()',              false)
  ) as want(role_name, sig, should)
),

-- ---------------------------------------------------------------------------
-- 8. Row level security
-- ---------------------------------------------------------------------------

c_rls_enabled as (
  select 'FAIL', '8. RLS', 'row level security on public.' || cl.relname,
         case when cl.relrowsecurity then 'OK' else 'FAIL' end,
         case when cl.relrowsecurity then 'enabled'
              else 'DISABLED — every row is readable by any signed-in user' end
  from pg_class cl
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public' and cl.relname in ('profiles', 'appointments', 'admins')
),

c_rls_all_public_tables as (
  select 'FAIL', '8. RLS', 'no public table left without RLS',
         case when count(*) = 0 then 'OK' else 'FAIL' end,
         coalesce(string_agg(cl.relname, ', '), 'clean')
  from pg_class cl
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public' and cl.relkind = 'r' and not cl.relrowsecurity
),

c_policies_missing as (
  select 'FAIL', '8. RLS', 'policy ' || e.pol,
         case when p.policyname is null then 'FAIL'
              when upper(p.cmd) is distinct from e.cmd then 'FAIL'
              else 'OK' end,
         case when p.policyname is null then 'MISSING'
              else p.cmd || ' | using: ' || coalesce(p.qual, '—') ||
                   ' | with check: ' || coalesce(p.with_check, '—') end
  from expected_policies e
  left join pg_policies p
    on p.schemaname = 'public' and p.tablename = e.tbl and p.policyname = e.pol
),

c_policies_extra as (
  select 'WARN', '8. RLS', 'unexpected policy ' || p.policyname, 'WARN',
         p.tablename || ' | ' || p.cmd || ' | using: ' || coalesce(p.qual, '—')
  from pg_policies p
  left join expected_policies e
    on e.tbl = p.tablename and e.pol = p.policyname
  where p.schemaname = 'public' and e.pol is null
),

c_no_delete_policy as (
  select 'FAIL', '8. RLS', 'no DELETE policy anywhere (bookings are cancelled, never erased)',
         case when count(*) = 0 then 'OK' else 'FAIL' end,
         coalesce(string_agg(tablename || '.' || policyname, ', '), 'clean')
  from pg_policies
  where schemaname = 'public' and upper(cmd) in ('DELETE', 'ALL')
),

c_no_admin_insert as (
  select 'WARN', '8. RLS', 'no INSERT policy for staff on appointments',
         case when count(*) = 0 then 'OK' else 'WARN' end,
         case when count(*) = 0 then 'clean — staff cannot create bookings, as designed'
              else string_agg(policyname, ', ') end
  from pg_policies
  where schemaname = 'public' and tablename = 'appointments'
    and upper(cmd) = 'INSERT' and policyname <> 'appointments_insert_own'
),

c_admins_not_enumerable as (
  select 'FAIL', '8. RLS', 'admins table is not enumerable',
         case when count(*) = 1 then 'OK' else 'FAIL' end,
         'policies on admins: ' || coalesce(string_agg(policyname || ' (' || cmd || ')', ', '), 'none') ||
         '  (expected exactly admins_select_self (SELECT))'
  from pg_policies where schemaname = 'public' and tablename = 'admins'
),

-- ---------------------------------------------------------------------------
-- 9. Anything else that appeared in this project along the way
-- ---------------------------------------------------------------------------

c_extra_tables as (
  select 'WARN', '9. strays', 'unexpected table public.' || cl.relname, 'WARN',
         'not part of the migrations — left over from an experiment?'
  from pg_class cl
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public' and cl.relkind = 'r'
    and cl.relname not in ('profiles', 'appointments', 'admins')
),

c_extra_definers as (
  select 'FAIL', '9. strays', 'unexpected security definer function ' || n.nspname || '.' || p.proname, 'FAIL',
         'security definer functions bypass RLS — every one of them is a way in'
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and p.proname not in ('booked_slots', 'is_admin')
),

all_checks as (
  select * from c_objects
  union all select * from c_enum
  union all select * from c_columns_missing
  union all select * from c_columns_extra
  union all select * from c_unique_index
  union all select * from c_lookup_index
  union all select * from c_named_constraint
  union all select * from c_fk_cascade
  union all select * from c_constraint_inventory
  union all select * from c_triggers
  union all select * from c_functions
  union all select * from c_grants
  union all select * from c_rls_enabled
  union all select * from c_rls_all_public_tables
  union all select * from c_policies_missing
  union all select * from c_policies_extra
  union all select * from c_no_delete_policy
  union all select * from c_no_admin_insert
  union all select * from c_admins_not_enumerable
  union all select * from c_extra_tables
  union all select * from c_extra_definers
)

select status, area, check_name, detail
from all_checks
order by
  case status when 'FAIL' then 0 when 'WARN' then 1 when 'OK' then 2 else 3 end,
  area,
  check_name;
