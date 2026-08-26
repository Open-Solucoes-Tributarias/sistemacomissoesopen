-- ============================================================
-- Migração 7: quem EFETIVAMENTE fez a venda
-- ============================================================
-- O PROBLEMA
-- Na aba Sistema a comissão de uma venda é dividida entre várias
-- vendedoras. O Painel da Equipe não tinha como saber de quem era a
-- venda, então creditava o contrato inteiro — e mais uma unidade em
-- "qtd. sistemas vendidos" — para CADA pessoa com comissão nela.
--
-- No banco real isso dava: R$ 4.336.963,30 e 123 sistemas "vendidos",
-- contra R$ 984.411,80 e 36 vendas de verdade. Nenhuma venda tinha uma
-- vendedora só: todas eram divididas entre 2 e 6 pessoas.
--
-- A SOLUÇÃO
-- Cada lançamento do Sistema passa a dizer quem fez a venda
-- (vendas.vendedor_responsavel), preenchido na coluna "Quem vendeu" da
-- própria aba. O painel conta essa pessoa, uma vez, e ponto.
--
-- Venda sem responsável NÃO é chutada para ninguém: fica de fora do
-- painel, e o sistema mostra quantas estão assim para serem preenchidas.
-- Como nenhuma venda antiga tem uma vendedora única, não dá para
-- preencher isso automaticamente — a informação não existe nos dados.
-- ============================================================

alter table vendas add column if not exists vendedor_responsavel text;

-- ------------------------------------------------------------
-- vendas_safe: o nome da responsável entra com a mesma máscara de
-- vendedor2/vendedor3 — a pessoa só lê se for ela mesma (ou admin).
-- Quem é responsável passa também a enxergar a venda, mesmo sem
-- comissão nela.
-- ------------------------------------------------------------
create or replace view vendas_safe with (security_barrier = true) as
select
  id, ano, mes, cliente, venda, valor, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor2,   current_user_person_name()) then vendedor2   else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor3,   current_user_person_name()) then vendedor3   else null end as vendedor3,
  pago, mes_pagamento, parcela_label, created_at, updated_at,
  case when current_user_is_admin() or name_matches(vendedor_responsavel, current_user_person_name()) then vendedor_responsavel else null end as vendedor_responsavel
from vendas
where current_user_is_admin()
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or name_matches(vendedor_responsavel, current_user_person_name())
   or exists (
     -- valor nulo = linha em branco que o app cria pra toda vendedora em
     -- toda venda; não significa que a pessoa participou daquela venda.
     select 1 from vendas_comissoes vc join sellers s on s.key = vc.seller_key
     where vc.venda_id = vendas.id
       and vc.valor is not null
       and name_matches(s.label, current_user_person_name())
   );

revoke all on vendas_safe from anon;
grant select on vendas_safe to authenticated;

-- ------------------------------------------------------------
-- painel_equipe_totais: o trecho de "sistemas vendidos" passa a olhar a
-- responsável, e não mais a lista de quem ganha comissão. Cursos segue
-- creditando todas as vendedoras do lançamento (lá o rateio ainda não
-- tem uma responsável marcada).
-- ------------------------------------------------------------
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

  -- 2. cursos vendidos (todas as vendedoras do lançamento)
  select x.vendedor, x.ano, x.mes, 0,0,0,0,0,0, x.valor_contrato, 0, 0
    from (
      select distinct l.id, btrim(v.vendedor) as vendedor, l.ano, l.mes, l.valor_contrato
        from lancamentos l
        cross join lateral (values (l.vendedor), (l.vendedor2), (l.vendedor3)) v(vendedor)
       where l.entidade = 'cursos' and coalesce(btrim(v.vendedor), '') <> ''
      union
      select distinct l.id, btrim(ev.vendedor), l.ano, l.mes, l.valor_contrato
        from lancamentos l
        join lancamentos_extra_vendedores ev on ev.lancamento_id = l.id
       where l.entidade = 'cursos' and coalesce(btrim(ev.vendedor), '') <> ''
    ) x

  union all

  -- 3. sistemas vendidos: uma venda, uma vendedora
  select btrim(vd.vendedor_responsavel), vd.ano, vd.mes, 0,0,0,0,0,0, 0, vd.valor, 1
    from vendas vd
   where coalesce(btrim(vd.vendedor_responsavel), '') <> ''
) t
group by btrim(vendedor), ano, mes;

alter view painel_equipe_totais owner to postgres;
revoke all on painel_equipe_totais from anon;
grant select on painel_equipe_totais to authenticated;

-- Quantas vendas ainda estão sem responsável, por mês.
create or replace view vendas_sem_responsavel with (security_barrier = true) as
select ano, mes, count(*) as qtd, sum(valor) as valor
  from vendas
 where coalesce(btrim(vendedor_responsavel), '') = ''
 group by ano, mes;

alter view vendas_sem_responsavel owner to postgres;
revoke all on vendas_sem_responsavel from anon;
grant select on vendas_sem_responsavel to authenticated;
