-- Operação TMS A2M: pedidos sem dados de cliente/endereço e gestão de exceções.
-- Execute no SQL Editor do projeto Supabase configurado no portal.
create table if not exists public.tms_imports (
  id uuid primary key default gen_random_uuid(),
  source_file text not null,
  status text not null default 'importing' check (status in ('importing', 'ready')),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.tms_orders (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null references public.tms_imports(id) on delete cascade,
  order_ref text not null,
  cd text,
  municipality text,
  bairro text,
  service_type text not null,
  status text,
  deadline_flag text,
  priority text,
  delivery_date date not null,
  deadline_time time,
  included_at timestamptz,
  route_started_at timestamptz,
  finished_at timestamptz,
  courier text,
  route_name text,
  route_seconds integer,
  service_seconds integer,
  courier_rating numeric(5,2),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Novos tempos de processo e posição aproximada do centro/região operacional.
-- Os timestamps de faturamento e separação são opcionais se o relatório não os trouxer.
alter table public.tms_orders
  add column if not exists municipality text,
  add column if not exists bairro text,
  add column if not exists included_time time,
  add column if not exists billed_time time,
  add column if not exists separated_time time,
  add column if not exists billed_at timestamptz,
  add column if not exists separated_at timestamptz,
  add column if not exists times_updated_by uuid references auth.users(id) on delete set null,
  add column if not exists times_updated_at timestamptz,
  add column if not exists region text,
  add column if not exists region_latitude numeric(9,6),
  add column if not exists region_longitude numeric(9,6);

alter table public.tms_orders
  add column if not exists inclusion_to_billing_seconds integer generated always as (
    case when included_at is not null and billed_at is not null and billed_at >= included_at
      then round(extract(epoch from (billed_at - included_at)))::integer else null end
  ) stored,
  add column if not exists billing_to_separation_seconds integer generated always as (
    case when billed_at is not null and separated_at is not null and separated_at >= billed_at
      then round(extract(epoch from (separated_at - billed_at)))::integer else null end
  ) stored,
  add column if not exists delivery_seconds integer generated always as (
    case when route_started_at is not null and finished_at is not null and finished_at >= route_started_at
      then round(extract(epoch from (finished_at - route_started_at)))::integer
      else route_seconds end
  ) stored,
  add column if not exists inclusion_to_billing_clock_seconds integer generated always as (
    case when included_time is not null and billed_time is not null
      then round(extract(epoch from (billed_time - included_time +
        case when billed_time < included_time then interval '1 day' else interval '0 seconds' end)))::integer
      else null end
  ) stored,
  add column if not exists billing_to_separation_clock_seconds integer generated always as (
    case when billed_time is not null and separated_time is not null
      then round(extract(epoch from (separated_time - billed_time +
        case when separated_time < billed_time then interval '1 day' else interval '0 seconds' end)))::integer
      else null end
  ) stored;

create index if not exists tms_orders_import_region_idx on public.tms_orders (import_id, region);

create table if not exists public.tms_exceptions (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null references public.tms_imports(id) on delete cascade,
  order_id uuid not null references public.tms_orders(id) on delete cascade,
  category text not null,
  severity text not null default 'media' check (severity in ('alta', 'media', 'baixa')),
  status text not null default 'aberto' check (status in ('aberto', 'em_andamento', 'resolvido', 'ignorado')),
  assigned_to text,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (import_id, order_id, category)
);

create index if not exists tms_orders_import_date_idx on public.tms_orders (import_id, delivery_date);
create index if not exists tms_orders_import_courier_idx on public.tms_orders (import_id, courier);
create index if not exists tms_exceptions_import_status_idx on public.tms_exceptions (import_id, status, severity);
alter table public.tms_imports enable row level security;
alter table public.tms_orders enable row level security;
alter table public.tms_exceptions enable row level security;

drop policy if exists "authenticated read ready tms imports" on public.tms_imports;
create policy "authenticated read ready tms imports" on public.tms_imports
for select to authenticated using (status = 'ready');
drop policy if exists "admin manages tms imports" on public.tms_imports;
create policy "admin manages tms imports" on public.tms_imports
for all to authenticated using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read ready tms orders" on public.tms_orders;
create policy "authenticated read ready tms orders" on public.tms_orders
for select to authenticated using (
  exists (select 1 from public.tms_imports i where i.id = import_id and i.status = 'ready')
);
drop policy if exists "admin manages tms orders" on public.tms_orders;
create policy "admin manages tms orders" on public.tms_orders
for all to authenticated using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read ready tms exceptions" on public.tms_exceptions;
create policy "authenticated read ready tms exceptions" on public.tms_exceptions
for select to authenticated using (
  exists (select 1 from public.tms_imports i where i.id = import_id and i.status = 'ready')
);
drop policy if exists "authenticated update tms exception workflow" on public.tms_exceptions;
create policy "authenticated update tms exception workflow" on public.tms_exceptions
for update to authenticated using (
  exists (select 1 from public.tms_imports i where i.id = import_id and i.status = 'ready')
) with check (auth.uid() is not null and updated_by = auth.uid());
drop policy if exists "authenticated add deadline validation exception" on public.tms_exceptions;
create policy "authenticated add deadline validation exception" on public.tms_exceptions
for insert to authenticated with check (
  category = 'Entrega concluída após o horário limite'
  and created_by = auth.uid()
  and exists (select 1 from public.tms_imports i where i.id = import_id and i.status = 'ready')
);
drop policy if exists "admin manages tms exceptions" on public.tms_exceptions;
create policy "admin manages tms exceptions" on public.tms_exceptions
for all to authenticated using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

-- Upload and replacement are limited to administrators; operators can only
-- edit triage fields on an exception (status, owner and note).
grant select, insert, update, delete on public.tms_imports to authenticated;
grant select, insert, update, delete on public.tms_orders to authenticated;
revoke update on public.tms_orders from authenticated;
grant update (included_time, billed_time, separated_time, deadline_time, finished_at, times_updated_by, times_updated_at) on public.tms_orders to authenticated;
grant select, insert, update, delete on public.tms_exceptions to authenticated;
revoke update on public.tms_exceptions from authenticated;
grant update (status, assigned_to, note, updated_by, updated_at) on public.tms_exceptions to authenticated;

create or replace function public.keep_latest_tms_import()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.tms_imports i
  where i.status = 'ready' and i.id <> (
    select newest.id from public.tms_imports newest
    where newest.status = 'ready'
    order by newest.created_at desc, newest.id desc limit 1
  );
  return new;
end;
$$;
drop trigger if exists keep_latest_tms_import on public.tms_imports;
create trigger keep_latest_tms_import after update of status on public.tms_imports
for each row when (old.status is distinct from new.status and new.status = 'ready')
execute function public.keep_latest_tms_import();
