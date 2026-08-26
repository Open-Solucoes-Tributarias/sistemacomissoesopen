-- ============================================================
-- Migração 6: Painel de relatórios mensais da equipe
-- ============================================================
-- Guarda os indicadores de ANDAMENTO que a equipe lança à mão a cada
-- mês (interação, propostas, prospecção, reuniões...), diferente do
-- resto do sistema, que calcula em cima dos lançamentos de venda.
--
-- Uma linha por vendedora e mês — daí o unique(ano, mes, vendedor),
-- que também impede lançar o mesmo mês duas vezes para a mesma pessoa.
--
-- ATENÇÃO (revisão de agosto/2026): os três indicadores de venda
-- (vendas de cursos, vendas de sistemas e quantidade de sistemas)
-- DEIXARAM de ser digitados. Eles agora saem sozinhos dos lançamentos
-- que já existem no sistema — ver a view painel_equipe_totais no fim
-- deste arquivo. Se você estiver aplicando tudo do zero, crie a tabela
-- já sem essas colunas; se já tinha a tabela antiga, rode o
-- "alter table ... drop column" logo abaixo.
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(ano, mes, vendedor)
);
create index if not exists relatorios_equipe_ano_mes on relatorios_equipe (ano, mes);

-- Se a tabela já existia com os campos de venda digitados, tire-os:
alter table relatorios_equipe drop column if exists vendas_cursos;
alter table relatorios_equipe drop column if exists vendas_sistemas;
alter table relatorios_equipe drop column if exists qtd_sistemas;

alter table relatorios_equipe enable row level security;

-- Mesmo corte do resto do sistema: admin vê e edita tudo; conta restrita
-- só enxerga a própria linha, e não edita.
drop policy if exists "select own or admin" on relatorios_equipe;
drop policy if exists "admin insert" on relatorios_equipe;
drop policy if exists "admin update" on relatorios_equipe;
drop policy if exists "admin delete" on relatorios_equipe;
create policy "select own or admin" on relatorios_equipe for select to authenticated
  using (current_user_is_admin() or name_matches(vendedor, current_user_person_name()));
create policy "admin insert" on relatorios_equipe for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on relatorios_equipe for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on relatorios_equipe for delete to authenticated using (current_user_is_admin());

-- ============================================================
-- painel_equipe_totais — o painel montado
-- ============================================================
-- Junta, por vendedora / ano / mês:
--   1. os indicadores de andamento digitados em relatorios_equipe;
--   2. VENDAS DE CURSOS: o valor do contrato de cada lançamento da aba
--      Cursos, creditado a cada vendedora que participou dele — seja
--      pelos campos vendedor / vendedor2 / vendedor3, seja pela lista de
--      vendedores extras. O DISTINCT por lançamento evita contar o mesmo
--      contrato duas vezes para a mesma pessoa;
--   3. VENDAS DE SISTEMAS: cada venda da aba Sistema, creditada a quem
--      tem comissão preenchida nela (vc.valor is not null — linha de
--      comissão vazia não é participação), somando o valor e contando 1
--      em qtd_sistemas.
--
-- É uma view AGREGADA e de propósito visível para todo mundo: a Soraya
-- pediu que o ranking aparecesse para todas as contas. Ela devolve
-- apenas totais por pessoa/mês — nunca o cliente, o contrato ou o
-- percentual de comissão de ninguém. Como roda com security_barrier e é
-- de dono postgres, ela passa por cima do RLS das tabelas de origem;
-- é justamente isso que permite a conta restrita ver o ranking sem
-- enxergar os lançamentos dos colegas.
-- ============================================================

create or replace view painel_equipe_totais with (security_barrier = true) as
select
  btrim(vendedor) as vendedor,
  ano,
  mes,
  sum(interacao)        as interacao,
  sum(propostas)        as propostas,
  sum(prospeccao_zero)  as prospeccao_zero,
  sum(prospeccao)       as prospeccao,
  sum(negocios_abertos) as negocios_abertos,
  sum(reunioes)         as reunioes,
  sum(vendas_cursos)    as vendas_cursos,
  sum(vendas_sistemas)  as vendas_sistemas,
  sum(qtd_sistemas)     as qtd_sistemas
from (
  -- 1. indicadores de andamento (digitados)
  select vendedor, ano, mes,
         interacao, propostas, prospeccao_zero, prospeccao, negocios_abertos, reunioes,
         0::numeric as vendas_cursos, 0::numeric as vendas_sistemas, 0::numeric as qtd_sistemas
    from relatorios_equipe

  union all

  -- 2. cursos vendidos (calculado)
  select x.vendedor, x.ano, x.mes,
         0, 0, 0, 0, 0, 0,
         x.valor_contrato, 0, 0
    from (
      select distinct l.id, btrim(v.vendedor) as vendedor, l.ano, l.mes, l.valor_contrato
        from lancamentos l
        cross join lateral (values (l.vendedor), (l.vendedor2), (l.vendedor3)) v(vendedor)
       where l.entidade = 'cursos'
         and coalesce(btrim(v.vendedor), '') <> ''
      union
      select distinct l.id, btrim(ev.vendedor), l.ano, l.mes, l.valor_contrato
        from lancamentos l
        join lancamentos_extra_vendedores ev on ev.lancamento_id = l.id
       where l.entidade = 'cursos'
         and coalesce(btrim(ev.vendedor), '') <> ''
    ) x

  union all

  -- 3. sistemas vendidos (calculado)
  select s.label, vd.ano, vd.mes,
         0, 0, 0, 0, 0, 0,
         0, vd.valor, 1
    from vendas vd
    join vendas_comissoes vc on vc.venda_id = vd.id and vc.valor is not null
    join sellers s on s.key = vc.seller_key
) t
group by btrim(vendedor), ano, mes;

alter view painel_equipe_totais owner to postgres;
revoke all on painel_equipe_totais from anon;
grant select on painel_equipe_totais to authenticated;
