-- ============================================================
-- Migração 7: quem EFETIVAMENTE fez a venda (Sistema e Cursos)
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
--
-- A ABA CURSOS TEM O MESMO PROBLEMA, em outro formato: lá os campos
-- "Vendedor / Vendedor 2 / Vendedor 3" também dizem quem ganha comissão.
-- Nos dados reais a mesma pessoa aparece como vendedora em 10 dos 12
-- cursos, com 1% em todos — é o papel dela na comissão, não a venda.
-- Por isso lancamentos ganha a mesma coluna, e também não é preenchida
-- automaticamente: copiar o campo "Vendedor" repetiria justamente o erro.
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
-- lancamentos_safe: mesma máscara para o nome da responsável do curso.
-- ------------------------------------------------------------
alter table lancamentos add column if not exists vendedor_responsavel text;

create or replace view lancamentos_safe with (security_barrier = true) as
select
  id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then vendedor  else null end as vendedor,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then comissao_percent  else null end as comissao_percent,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then vendedor2 else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then comissao_percent2 else null end as comissao_percent2,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then vendedor3 else null end as vendedor3,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then comissao_percent3 else null end as comissao_percent3,
  pago, mes_pagamento, parcela_label, created_at, updated_at,
  case when current_user_is_admin() or name_matches(vendedor_responsavel, current_user_person_name()) then vendedor_responsavel else null end as vendedor_responsavel
from lancamentos
where current_user_is_admin()
   or name_matches(vendedor,  current_user_person_name())
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or name_matches(vendedor_responsavel, current_user_person_name())
   or lancamento_tem_extra_vendedor_meu(id);

revoke all on lancamentos_safe from anon;
grant select on lancamentos_safe to authenticated;

-- ------------------------------------------------------------
-- painel_equipe_totais: uma venda, uma vendedora — vale para os dois
-- lados, sistemas e cursos.
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

  -- 2. cursos vendidos: um lançamento, uma vendedora
  select btrim(l.vendedor_responsavel), l.ano, l.mes, 0,0,0,0,0,0, l.valor_contrato, 0, 0
    from lancamentos l
   where l.entidade = 'cursos'
     and coalesce(btrim(l.vendedor_responsavel), '') <> ''

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

-- Quantos lançamentos ainda estão sem responsável, por mês.
create or replace view vendas_sem_responsavel with (security_barrier = true) as
select ano, mes, count(*) as qtd, sum(valor) as valor
  from vendas
 where coalesce(btrim(vendedor_responsavel), '') = ''
 group by ano, mes;

create or replace view cursos_sem_responsavel with (security_barrier = true) as
select ano, mes, count(*) as qtd, sum(valor_contrato) as valor
  from lancamentos
 where entidade = 'cursos'
   and coalesce(btrim(vendedor_responsavel), '') = ''
 group by ano, mes;

alter view vendas_sem_responsavel  owner to postgres;
alter view cursos_sem_responsavel  owner to postgres;
revoke all on vendas_sem_responsavel, cursos_sem_responsavel from anon;
grant select on vendas_sem_responsavel, cursos_sem_responsavel to authenticated;
