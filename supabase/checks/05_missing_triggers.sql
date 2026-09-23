-- Minerva Nail Art — reattaching two rules whose triggers did not land.
--
-- Safe to run. It creates nothing new: both functions already exist and both
-- already raise their codes; only the triggers that call them are missing, so
-- the rules they carry are not being enforced.
--
-- The audit on 2026-09-23 reported:
--
--   FAIL  5. triggers  appointments_enforce_window   MISSING
--   FAIL  5. triggers  appointments_reject_closed    MISSING
--
-- Which means, right now, the database would accept a customer booking twice
-- in the same week, and would accept a booking on a Sunday. Everything else
-- came back green.
--
-- The schema file now drops each trigger before creating it, so re-running it
-- repairs a partial apply. This file exists because re-running the whole
-- schema is a bigger hammer than the situation needs.

drop trigger if exists appointments_enforce_window on public.appointments;
create trigger appointments_enforce_window
  before insert or update on public.appointments
  for each row execute function public.enforce_booking_window();

drop trigger if exists appointments_reject_closed on public.appointments;
create trigger appointments_reject_closed
  before insert or update on public.appointments
  for each row execute function public.reject_closed_days();

-- Both should now be listed. Expect two rows.

select tgname                     as trigger_name,
       pg_get_triggerdef(t.oid)   as definition
from pg_trigger t
where not t.tgisinternal
  and t.tgrelid = to_regclass('public.appointments')
  and tgname in ('appointments_enforce_window', 'appointments_reject_closed')
order by tgname;

-- Then re-run 01_schema_audit.sql. Zero FAIL is the finish line.
