-- ============================================================
-- Migração 6: Painel de relatórios mensais da equipe
-- ============================================================
-- Guarda os indicadores de ANDAMENTO que a equipe lança à mão a cada
-- mês (interação, propostas, prospecção, reuniões...), diferente do
-- resto do sistema, que calcula em cima dos lançamentos de venda.
--
-- Uma linha por vendedora e mês — daí o unique(ano, mes, vendedor),
-- que também impede lançar o mesmo mês duas vezes para a mesma pessoa.
-- ============================================================

create table if not exists relatorios_equipe (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  vendedor text not null,
  interacao numeric not null default 0,
  propostas numeric not null default 0,
  prospeccao_zero numeric not null default 0,
  prospeccao numeric not null default 0,
  negocios_abertos numeric not null default 0,
  reunioes numeric not null default 0,
  vendas_cursos numeric not null default 0,
  vendas_sistemas numeric not null default 0,
  qtd_sistemas numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(ano, mes, vendedor)
);
create index if not exists relatorios_equipe_ano_mes on relatorios_equipe (ano, mes);

alter table relatorios_equipe enable row level security;

-- Mesmo corte do resto do sistema: admin vê e edita tudo; conta restrita
-- só enxerga a própria linha, e não edita. Por isso o ranking e o
-- comparativo entre pessoas ficam escondidos para quem é restrito — sem
-- os dados dos colegas eles não fariam sentido.
create policy "select own or admin" on relatorios_equipe for select to authenticated
  using (current_user_is_admin() or name_matches(vendedor, current_user_person_name()));
create policy "admin insert" on relatorios_equipe for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on relatorios_equipe for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on relatorios_equipe for delete to authenticated using (current_user_is_admin());
