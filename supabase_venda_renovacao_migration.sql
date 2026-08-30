-- ============================================================
-- Migração 17: renovação não conta no ranking
-- ============================================================
-- A renovação confirmada vira venda na aba Sistema e vale comissão como
-- qualquer outra — isso está certo. O que não pode é ela contar no
-- RANKING de desempenho: renovar um contrato que já era da casa não é a
-- mesma coisa que trazer cliente novo, e a carteira de renovação é grande
-- o bastante (quase 200 empresas) para decidir sozinha quem é campeã.
--
-- Daí uma coluna própria em vendas, e não um texto na observação: o corte
-- mexe em desempenho, e não pode depender de alguém digitar a palavra
-- certa. A tela mostra o selo "♻️ Renovação" e um botão para marcar ou
-- desmarcar qualquer venda.
--
-- A view painel_equipe_totais passa a ignorar essas vendas. Elas continuam
-- inteiras no Resumo Geral, nas comissões e no faturamento do mês.
-- ============================================================

alter table vendas add column if not exists renovacao boolean not null default false;

-- O que já foi lançado a partir da aba de renovações, e o que ficou
-- marcado só pela observação, entram na regra nova.
update vendas v set renovacao = true
  from renovacoes r where r.venda_id = v.id and v.renovacao = false;
update vendas set renovacao = true
 where renovacao = false and btrim(lower(coalesce(observacoes,''))) = 'renovação';

create or replace view painel_equipe_totais with (security_barrier = true) as
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
  select vendedor, ano, mes,
         interacao, propostas, prospeccao_zero, prospeccao, negocios_abertos, reunioes,
         0::numeric as vendas_cursos, 0::numeric as vendas_sistemas, 0::numeric as qtd_sistemas,
         contratos
    from relatorios_equipe

  union all

  select btrim(lv.vendedor), l.ano, l.mes,
         0, 0, 0, 0, 0, 0, lv.valor, 0, 0, 0
    from lancamento_vendas lv
    join lancamentos l on l.id = lv.lancamento_id
   where l.entidade = 'cursos'
     and coalesce(btrim(lv.vendedor),'') <> ''
     and lv.valor is not null

  union all

  -- venda de renovação fica de fora: continua valendo comissão na aba
  -- Sistema, mas não é venda nova e não deve mexer no desempenho
  select btrim(vd.vendedor_responsavel), vd.ano, vd.mes,
         0, 0, 0, 0, 0, 0, 0, vd.valor, 1, 0
    from vendas vd
   where coalesce(btrim(vd.vendedor_responsavel),'') <> ''
     and vd.renovacao = false
) t
group by btrim(vendedor), ano, mes;

alter view painel_equipe_totais owner to postgres;
revoke all on painel_equipe_totais from anon;
grant select on painel_equipe_totais to authenticated;
