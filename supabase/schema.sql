-- A2M Portal: schema inicial para autenticação e dados operacionais privados.
-- Execute no SQL Editor do projeto Supabase.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'operador' check (role in ('admin', 'operador')),
  created_at timestamptz not null default now()
);

create or replace function public.current_a2m_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.create_a2m_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_a2m_user_created on auth.users;
create trigger on_a2m_user_created
after insert on auth.users
for each row execute procedure public.create_a2m_profile();

create table if not exists public.shelf_life_items (
  id uuid primary key default gen_random_uuid(),
  warehouse text not null,
  segment text,
  item_id text,
  product_code text,
  product text not null,
  unit text,
  stock_quantity numeric(14,3) not null default 0,
  reserved_quantity numeric(14,3) not null default 0,
  adjustment_quantity numeric(14,3) not null default 0,
  difference_quantity numeric(14,3) not null default 0,
  unit_cost numeric(14,4) not null default 0,
  expiry_date date not null,
  source_file text,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Cada carga é publicada somente depois de todos os lotes serem gravados.
-- Cargas incompletas ficam invisíveis para os operadores.
create table if not exists public.shelf_life_imports (
  id uuid primary key default gen_random_uuid(),
  source_file text not null,
  status text not null default 'importing' check (status in ('importing', 'ready')),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.shelf_life_items
  add column if not exists import_id uuid references public.shelf_life_imports(id) on delete cascade;

create index if not exists shelf_life_expiry_idx on public.shelf_life_items (expiry_date);
create index if not exists shelf_life_warehouse_idx on public.shelf_life_items (warehouse);

create table if not exists public.reconciliation_items (
  id uuid primary key default gen_random_uuid(),
  reconciliation_date date not null default current_date,
  warehouse text not null,
  item_id text,
  product text not null,
  system_quantity numeric(14,3) not null default 0,
  physical_quantity numeric(14,3) not null default 0,
  difference_quantity numeric(14,3) generated always as (physical_quantity - system_quantity) stored,
  unit_cost numeric(14,4) not null default 0,
  justification text,
  status text not null default 'pendente' check (status in ('pendente', 'conferido', 'aprovado')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reconciliation_imports (
  id uuid primary key default gen_random_uuid(),
  source_file text not null,
  status text not null default 'importing' check (status in ('importing', 'ready')),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.reconciliation_items
  add column if not exists import_id uuid references public.reconciliation_imports(id) on delete cascade,
  add column if not exists segment text,
  add column if not exists curve text,
  add column if not exists has_physical boolean not null default false;
alter table public.reconciliation_items drop constraint if exists reconciliation_items_status_check;

create index if not exists reconciliation_date_idx on public.reconciliation_items (reconciliation_date);
create index if not exists reconciliation_warehouse_idx on public.reconciliation_items (warehouse);

alter table public.profiles enable row level security;
alter table public.shelf_life_items enable row level security;
alter table public.shelf_life_imports enable row level security;
alter table public.reconciliation_items enable row level security;
alter table public.reconciliation_imports enable row level security;

drop policy if exists "profile self or admin read" on public.profiles;
create policy "profile self or admin read" on public.profiles
for select to authenticated
using (id = auth.uid() or public.current_a2m_role() = 'admin');

drop policy if exists "admin manages profiles" on public.profiles;
create policy "admin manages profiles" on public.profiles
for all to authenticated
using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read shelf life" on public.shelf_life_items;
create policy "authenticated read shelf life" on public.shelf_life_items
for select to authenticated using (
  exists (
    select 1 from public.shelf_life_imports i
    where i.id = import_id and i.status = 'ready'
  )
);

drop policy if exists "admin manages shelf life" on public.shelf_life_items;
create policy "admin manages shelf life" on public.shelf_life_items
for all to authenticated
using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read completed shelf life imports" on public.shelf_life_imports;
create policy "authenticated read completed shelf life imports" on public.shelf_life_imports
for select to authenticated using (status = 'ready');

drop policy if exists "admin manages shelf life imports" on public.shelf_life_imports;
create policy "admin manages shelf life imports" on public.shelf_life_imports
for all to authenticated
using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read reconciliation" on public.reconciliation_items;
create policy "authenticated read reconciliation" on public.reconciliation_items
for select to authenticated using (
  exists (
    select 1 from public.reconciliation_imports i
    where i.id = import_id and i.status = 'ready'
  )
);

drop policy if exists "authenticated update reconciliation counts" on public.reconciliation_items;
create policy "authenticated update reconciliation counts" on public.reconciliation_items
for update to authenticated
using (exists (select 1 from public.reconciliation_imports i where i.id = import_id and i.status = 'ready'))
with check (auth.uid() is not null);

drop policy if exists "admin manages reconciliation" on public.reconciliation_items;
create policy "admin manages reconciliation" on public.reconciliation_items
for all to authenticated
using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read completed reconciliation imports" on public.reconciliation_imports;
create policy "authenticated read completed reconciliation imports" on public.reconciliation_imports
for select to authenticated using (status = 'ready');

drop policy if exists "admin manages reconciliation imports" on public.reconciliation_imports;
create policy "admin manages reconciliation imports" on public.reconciliation_imports
for all to authenticated
using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

-- O RLS restringe as linhas; estes grants habilitam o acesso via API do Supabase.
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.shelf_life_items to authenticated;
grant select, insert, update, delete on public.shelf_life_imports to authenticated;
grant select, insert, update, delete on public.reconciliation_items to authenticated;
-- Operadores só alteram campos da contagem; dados-base importados ficam protegidos.
revoke update on public.reconciliation_items from authenticated;
grant update (physical_quantity, has_physical, justification, status, updated_at)
  on public.reconciliation_items to authenticated;
grant select, insert, update, delete on public.reconciliation_imports to authenticated;

-- KPIs de Estoque: uma carga versionada e publicada somente após o envio completo.
create table if not exists public.stock_kpi_imports (
  id uuid primary key default gen_random_uuid(),
  source_file text not null,
  status text not null default 'importing' check (status in ('importing', 'ready')),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_kpi_items (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null references public.stock_kpi_imports(id) on delete cascade,
  product_id text not null,
  product text not null,
  manufacturer text,
  segment text,
  subgroup text,
  turnover text,
  pull_status text,
  purchase_quantity numeric(14,3) not null default 0,
  observation text,
  stock_total numeric(14,3) not null default 0,
  sold_30d numeric(14,3) not null default 0,
  stored_value numeric(16,4) not null default 0,
  warehouse_stock jsonb not null default '{}'::jsonb,
  warehouse_value jsonb not null default '{}'::jsonb,
  warehouse_sales jsonb not null default '{}'::jsonb,
  coverage_days numeric(14,3) not null default 0,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.stock_kpi_items add column if not exists subgroup text;

create index if not exists stock_kpi_items_import_idx on public.stock_kpi_items (import_id);
alter table public.stock_kpi_imports enable row level security;
alter table public.stock_kpi_items enable row level security;

drop policy if exists "authenticated read completed stock kpi imports" on public.stock_kpi_imports;
create policy "authenticated read completed stock kpi imports" on public.stock_kpi_imports
for select to authenticated using (status = 'ready');

drop policy if exists "admin manages stock kpi imports" on public.stock_kpi_imports;
create policy "admin manages stock kpi imports" on public.stock_kpi_imports
for all to authenticated using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

drop policy if exists "authenticated read completed stock kpi items" on public.stock_kpi_items;
create policy "authenticated read completed stock kpi items" on public.stock_kpi_items
for select to authenticated using (
  exists (select 1 from public.stock_kpi_imports i where i.id = import_id and i.status = 'ready')
);

drop policy if exists "admin manages stock kpi items" on public.stock_kpi_items;
create policy "admin manages stock kpi items" on public.stock_kpi_items
for all to authenticated using (public.current_a2m_role() = 'admin')
with check (public.current_a2m_role() = 'admin');

grant select, insert, update, delete on public.stock_kpi_imports to authenticated;
grant select, insert, update, delete on public.stock_kpi_items to authenticated;

-- Índice usado ao localizar a versão publicada mais recente.
create index if not exists stock_kpi_imports_ready_idx
  on public.stock_kpi_imports (created_at desc, id desc)
  where status = 'ready';

-- A aplicação consulta os itens somente por import_id; este índice não é usado.
drop index if exists public.stock_kpi_items_product_idx;

-- Após uma carga ficar pronta, remove versões publicadas anteriores.
-- O ON DELETE CASCADE também elimina seus itens associados.
create or replace function public.keep_latest_stock_kpi_import()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.stock_kpi_imports i
  where i.status = 'ready'
    and i.id <> (
      select newest.id
      from public.stock_kpi_imports newest
      where newest.status = 'ready'
      order by newest.created_at desc, newest.id desc
      limit 1
    );
  return new;
end;
$$;

drop trigger if exists keep_latest_stock_kpi_import on public.stock_kpi_imports;
create trigger keep_latest_stock_kpi_import
after update of status on public.stock_kpi_imports
for each row
when (old.status is distinct from new.status and new.status = 'ready')
execute function public.keep_latest_stock_kpi_import();
