-- ============================================================
-- Migração 9: grupo de contratos e reuniões no relatório de desempenho
-- ============================================================
-- Nem todo mundo do comercial é acompanhado pelos mesmos indicadores.
-- Tem gente — o Davidson é o primeiro caso — medida por dois números só:
-- quantos contratos assinou e quantas reuniões realizou no mês.
--
-- Essas pessoas ficam numa lista PRÓPRIA dentro do Painel da Equipe,
-- separada da lista de vendedoras, e não entram no ranking de vendas —
-- que não faria sentido para quem não vende. Os números vão para a mesma
-- tabela relatorios_equipe, numa aba própria do painel.
-- ============================================================

alter table relatorios_equipe add column if not exists contratos numeric not null default 0;

-- A lista de quem é acompanhado assim mora em entity_vendors, do mesmo
-- jeito que a lista de quem aparece no painel de vendedoras.
alter table entity_vendors drop constraint if exists entity_vendors_entidade_check;
alter table entity_vendors add constraint entity_vendors_entidade_check
  check (entidade in ('consultoria','publicos','cursos','painel','painel_contratos'));

insert into entity_vendors (entidade, vendor_name)
values ('painel_contratos','Davidson')
on conflict (entidade, vendor_name) do nothing;

-- painel_equipe_totais passa a devolver contratos junto com o resto.
-- A coluna entra no fim: create or replace não aceita inserir coluna no meio.
drop view if exists painel_equipe_totais;
create view painel_equipe_totais with (security_barrier = true) as
select
  btrim(vendedor) as vendedor, ano, mes,
  sum(interacao)        as interacao,
  sum(propostas)        as propostas,
  sum(prospeccao_zero)  as prospeccao_zero,
  sum(prospeccao)       as prospeccao,
  sum(negocios_abertos) as negocios_abertos,
  sum(reunioes)         as reunioes,
  sum(vendas_cursos)    as vendas_cursos,
  sum(vendas_sistemas)  as vendas_sistemas,
  sum(qtd_sistemas)     as qtd_sistemas,
  sum(contratos)        as contratos
from (
  -- 1. indicadores digitados (inclui contratos)
  select vendedor, ano, mes,
         interacao, propostas, prospeccao_zero, prospeccao, negocios_abertos, reunioes,
         0::numeric as vendas_cursos, 0::numeric as vendas_sistemas, 0::numeric as qtd_sistemas,
         contratos
    from relatorios_equipe

  union all

  -- 2. cursos: quanto cada vendedora trouxe daquele faturamento
  select btrim(lv.vendedor), l.ano, l.mes, 0,0,0,0,0,0, lv.valor, 0, 0, 0
    from lancamento_vendas lv
    join lancamentos l on l.id = lv.lancamento_id
   where l.entidade = 'cursos'
     and coalesce(btrim(lv.vendedor), '') <> ''
     and lv.valor is not null

  union all

  -- 3. sistemas: uma venda, uma vendedora
  select btrim(vd.vendedor_responsavel), vd.ano, vd.mes, 0,0,0,0,0,0, 0, vd.valor, 1, 0
    from vendas vd
   where coalesce(btrim(vd.vendedor_responsavel), '') <> ''
) t
group by btrim(vendedor), ano, mes;

alter view painel_equipe_totais owner to postgres;
revoke all on painel_equipe_totais from anon;
grant select on painel_equipe_totais to authenticated;
