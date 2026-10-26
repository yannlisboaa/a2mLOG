-- Otimização incremental para uma instalação Supabase já existente.
-- Mantém os dados publicados durante a carga e descarta versões antigas
-- apenas depois que uma nova carga estiver completa.
begin;

alter table public.stock_kpi_items
  add column if not exists subgroup text;

create index if not exists stock_kpi_imports_ready_idx
  on public.stock_kpi_imports (created_at desc, id desc)
  where status = 'ready';

-- A tela filtra itens por import_id; o índice isolado em product_id não é usado.
drop index if exists public.stock_kpi_items_product_idx;

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

commit;

-- Limpeza única e opcional do histórico já existente.
-- Execute apenas se não precisar consultar versões antigas:
-- delete from public.stock_kpi_imports i
-- where i.status = 'ready'
--   and i.id <> (
--     select newest.id
--     from public.stock_kpi_imports newest
--     where newest.status = 'ready'
--     order by newest.created_at desc, newest.id desc
--     limit 1
--   );

-- Para remover cargas que ficaram incompletas há mais de 24 horas,
-- confirme que não há uma publicação em andamento e execute separadamente:
-- delete from public.stock_kpi_imports
-- where status = 'importing'
--   and created_at < now() - interval '24 hours';
