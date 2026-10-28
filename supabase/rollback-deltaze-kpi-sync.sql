-- Reverte somente os metadados adicionados pela preparação da sincronização Deltaze.
-- Execute este arquivo apenas se deltaze-kpi-sync.sql já tiver sido aplicado.
begin;

alter table public.stock_kpi_imports
  drop constraint if exists stock_kpi_imports_source_type_check;

alter table public.stock_kpi_imports
  drop constraint if exists stock_kpi_imports_status_check;

alter table public.stock_kpi_imports
  add constraint stock_kpi_imports_status_check
  check (status in ('importing', 'ready'));

alter table public.stock_kpi_imports
  drop column if exists source_type,
  drop column if exists api_period_start,
  drop column if exists api_period_end,
  drop column if exists stock_records_count,
  drop column if exists sales_records_count,
  drop column if exists returns_records_count,
  drop column if exists product_count,
  drop column if exists error_message,
  drop column if exists finished_at;

commit;
