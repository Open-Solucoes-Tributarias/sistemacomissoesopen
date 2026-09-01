-- ============================================================
-- Migração 25 — Curso In Company entra no ranking
-- ============================================================
-- Aplicada no banco como: curso_in_company
--
-- Curso in company é ministrado dentro da empresa cliente, sob medida —
-- um tipo de venda diferente de um curso aberto (online ou presencial
-- genérico). A Soraya quer que quem vende in company seja reconhecida
-- por isso no ranking, num indicador próprio, separado da métrica geral
-- de "vendas de cursos".
--
-- A marca é por lançamento (entidade='cursos' em `lancamentos`), com um
-- botão próprio na linha — não dá pra confiar em procurar "IN COMPANY"
-- no nome do curso pra sempre: é convenção de digitação, não dado.
alter table lancamentos add column if not exists in_company boolean not null default false;

-- Backfill de bom grado: os cursos já lançados cujo nome já segue a
-- convenção "IN COMPANY ..." que a equipe usa há tempos viram marcados
-- automaticamente, pra ninguém ter que retagear o histórico à mão.
update lancamentos set in_company = true
 where entidade = 'cursos' and in_company = false and nome ilike '%in company%';

-- Regra do projeto: coluna nova em lancamentos entra também na view
-- _safe, senão o app grava e nunca lê de volta.
create or replace view lancamentos_safe as
 select id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro,
        participacao, forma_pagamento, observacoes,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(colaborador, current_user_person_name())
             then colaborador else null::text end as colaborador,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor, current_user_person_name())
             then vendedor else null::text end as vendedor,
        case when current_user_is_admin()
                  or name_matches(vendedor, current_user_person_name())
             then comissao_percent else null::numeric end as comissao_percent,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor2, current_user_person_name())
             then vendedor2 else null::text end as vendedor2,
        case when current_user_is_admin()
                  or name_matches(vendedor2, current_user_person_name())
             then comissao_percent2 else null::numeric end as comissao_percent2,
        case when current_user_is_admin() or current_user_is_financeiro()
                  or name_matches(vendedor3, current_user_person_name())
             then vendedor3 else null::text end as vendedor3,
        case when current_user_is_admin()
                  or name_matches(vendedor3, current_user_person_name())
             then comissao_percent3 else null::numeric end as comissao_percent3,
        pago, mes_pagamento, parcela_label, created_at, updated_at,
        nota_emitida, nota_emitida_em,
        in_company
   from lancamentos
  where current_user_is_admin() or current_user_is_financeiro()
     or name_matches(vendedor, current_user_person_name())
     or name_matches(vendedor2, current_user_person_name())
     or name_matches(vendedor3, current_user_person_name())
     or name_matches(colaborador, current_user_person_name())
     or lancamento_tem_extra_vendedor_meu(id);

revoke all on lancamentos_safe from anon;
grant select on lancamentos_safe to authenticated;

-- Nova coluna na view do ranking: soma do faturamento de curso in
-- company por vendedora/mês/ano, igual à conta de "vendas_cursos", só
-- que restrita ao curso marcado.
create or replace view painel_equipe_totais as
select btrim(vendedor)      as vendedor,
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
       sum(qtd_sistemas)     as qtd_sistemas,
       sum(contratos)        as contratos,
       sum(vendas_cursos_incompany) as vendas_cursos_incompany
from (
  select vendedor, ano, mes,
         interacao, propostas, prospeccao_zero, prospeccao, negocios_abertos, reunioes,
         0::numeric as vendas_cursos, 0::numeric as vendas_sistemas, 0::numeric as qtd_sistemas,
         contratos, 0::numeric as vendas_cursos_incompany
    from relatorios_equipe

  union all

  select btrim(lv.vendedor), l.ano, l.mes,
         0, 0, 0, 0, 0, 0, lv.valor, 0, 0, 0,
         case when coalesce(l.in_company,false) then lv.valor else 0 end
    from lancamento_vendas lv
    join lancamentos l on l.id = lv.lancamento_id
   where l.entidade = 'cursos'
     and coalesce(btrim(lv.vendedor),'') <> ''
     and lv.valor is not null

  union all

  -- venda de renovação fica de fora: continua valendo comissão na aba
  -- Sistema, mas não é venda nova e não deve mexer no desempenho
  select btrim(vd.vendedor_responsavel), vd.ano, vd.mes,
         0, 0, 0, 0, 0, 0, 0, vd.valor, 1, 0, 0
    from vendas vd
   where coalesce(btrim(vd.vendedor_responsavel),'') <> ''
     and vd.renovacao = false
) t
group by btrim(vendedor), ano, mes;

alter view painel_equipe_totais owner to postgres;
revoke all on painel_equipe_totais from anon;
grant select on painel_equipe_totais to authenticated;
