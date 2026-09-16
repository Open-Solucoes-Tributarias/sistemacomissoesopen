-- ============================================================
-- Migração 31 — Planos premium saem de Sistema e vão para
--               "Consultorias e site para Órgãos Públicos"
-- ============================================================
-- APLICADA EM PRODUÇÃO em 15/09/2026. Registro do que foi feito.
--
-- Escopo: os 61 lançamentos cujo produto tinha "premium" no nome
--   GT Premium Mensal ... 60 vendas
--   GT Plano Premium ...... 1 venda
--   R$ 542.041,92 de contrato · R$ 81.059,43 de comissão em 224 linhas,
--   entre 7 vendedoras (Soraya, Arick, Gustavo, Angela, Rios, Luciana, Uilma).
--
-- ------------------------------------------------------------
-- A diferença de modelo entre as duas abas
-- ------------------------------------------------------------
-- Em `vendas`, a comissão de cada vendedora é um VALOR em R$
-- (vendas_comissoes.valor) — a % é só memória de cálculo.
-- Em `lancamentos`, é um PERCENTUAL, e o valor é derivado de
-- (valor do contrato − parte do parceiro).
--
-- Converter valor → percentual seria perigoso no geral, mas aqui era exato:
-- nenhuma venda premium tinha parceiro (a base é o valor cheio) e os
-- percentuais originais eram redondos, de 1% a 5%. A conferência fechou em
-- R$ 81.059,43 centavo por centavo.
--
-- ------------------------------------------------------------
-- O que não tinha campo no destino
-- ------------------------------------------------------------
-- `lancamentos` não tem produto, nem etiqueta de Renovação/Upgrade, nem
-- "quem vendeu" (esse último só existe em Sistema e Cursos). Os três foram
-- para Observações, na forma:
--     GT Premium Mensal · ♻️ Renovação · vendeu: Soraya · <observação original>
-- Nada se perdeu; mudou de lugar. É também por Observações que estes 61
-- lançamentos são identificáveis (ilike 'GT %Premium%').
--
-- ------------------------------------------------------------
-- Ids
-- ------------------------------------------------------------
-- Os ids de `lancamentos` são namespeados por aba, por convenção emergente
-- dos dados: consultoria em 1+, publicos em 100001+, cursos em 200001+. O
-- app calcula o próximo como max(id)+1 DA ABA, então os novos continuaram a
-- partir do maior id de publicos (100139 → 100140..100200).
--
-- ------------------------------------------------------------
-- Efeito no Relatório de Desempenho
-- ------------------------------------------------------------
-- Lançamento de Órgãos Públicos não alimenta os indicadores "Vendas de
-- sistemas" / "Qtd. sistemas vendidos" — só `vendas` alimenta. E a view
-- painel_equipe_totais já ignorava as marcadas como renovação, então das 61
-- só 11 contavam no ranking:
--     Luciana  −2 vendas  −R$ 101.266,66
--     Soraya   −9 vendas  −R$  68.999,94  (saiu do indicador: eram as únicas)
-- As comissões dessas pessoas seguem intactas; o que mudou é o indicador
-- de volume de venda de sistema.
--
-- ------------------------------------------------------------
-- Arredondamento dos percentuais
-- ------------------------------------------------------------
-- A divisão (comissão em R$ ÷ valor do contrato) devolveu 3,9999% onde a
-- intenção era 4%, porque o valor em R$ estava arredondado em centavos.
-- Em 11 das 224 linhas o desvio era de até 0,0007 ponto percentual. Foram
-- arredondadas para 2 casas: recupera o percentual pretendido, deixa a tela
-- legível, e move o total de comissão em R$ 0,16 para cima
-- (R$ 81.059,43 → R$ 81.059,59).
--
-- ------------------------------------------------------------
-- Backup e como desfazer
-- ------------------------------------------------------------
-- As tabelas _backup_vendas_premium_20260915 e
-- _backup_vendas_comissoes_premium_20260915 guardam as 61 vendas e as 224
-- comissões como estavam. Para desfazer:
--
--   insert into vendas select * from _backup_vendas_premium_20260915;
--   insert into vendas_comissoes select * from _backup_vendas_comissoes_premium_20260915;
--   delete from lancamentos_extra_vendedores where lancamento_id in (
--     select id from lancamentos where entidade='publicos' and observacoes ilike 'GT %Premium%');
--   delete from lancamentos where entidade='publicos' and observacoes ilike 'GT %Premium%';
--   insert into venda_products(name) values ('GT Premium Mensal'), ('GT Plano Premium');
--
-- Conferido que estava certo, as duas tabelas de backup podem cair.
--
-- ============================================================
-- O QUE FOI EXECUTADO
-- ============================================================

create temporary table _premium_mov as
with p as (
  select v.*, row_number() over (order by v.mes, v.cliente, v.id) as rn
    from vendas v where v.venda ilike '%premium%'
)
select p.*, (select coalesce(max(id), 100000) from lancamentos where entidade='publicos') + p.rn as novo_id
  from p;

create temporary table _premium_com as
select m.novo_id, s.label as vendedor,
       round(vc.valor / m.valor * 100.0, 4) as percent,
       row_number() over (partition by m.novo_id order by s.sort_order) as pos
  from _premium_mov m
  join vendas_comissoes vc on vc.venda_id = m.id
  join sellers s on s.key = vc.seller_key
 where vc.valor is not null and m.valor > 0;

insert into lancamentos (
  id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro, participacao,
  forma_pagamento, colaborador, observacoes,
  comissao_percent, vendedor, comissao_percent2, vendedor2, comissao_percent3, vendedor3,
  pago, mes_pagamento, nota_emitida, nota_emitida_em, in_company
)
select m.novo_id, 'publicos', m.ano, m.mes, m.cliente, m.valor, null, '', null,
       coalesce(m.forma_pagamento,''), coalesce(m.colaborador,''),
       concat_ws(' · ',
         m.venda,
         case when m.renovacao then '♻️ Renovação'
              when m.upgrade then '⬆️ Upgrade'
              when m.novo_contrato then '✨ Contrato novo' end,
         nullif('vendeu: ' || coalesce(nullif(trim(m.vendedor_responsavel),''), ''), 'vendeu: '),
         nullif(trim(coalesce(m.observacoes,'')), '')
       ),
       (select c.percent  from _premium_com c where c.novo_id=m.novo_id and c.pos=1),
       (select c.vendedor from _premium_com c where c.novo_id=m.novo_id and c.pos=1),
       (select c.percent  from _premium_com c where c.novo_id=m.novo_id and c.pos=2),
       (select c.vendedor from _premium_com c where c.novo_id=m.novo_id and c.pos=2),
       (select c.percent  from _premium_com c where c.novo_id=m.novo_id and c.pos=3),
       (select c.vendedor from _premium_com c where c.novo_id=m.novo_id and c.pos=3),
       m.pago, m.mes_pagamento, m.nota_emitida, m.nota_emitida_em, false
  from _premium_mov m;

-- da 4ª vendedora em diante (16 das 61 vendas tinham 4 a 7 vendedoras)
insert into lancamentos_extra_vendedores (lancamento_id, vendedor, percent)
select c.novo_id, c.vendedor, c.percent from _premium_com c where c.pos > 3;

-- sai de Sistema: a comissão primeiro, que referencia a venda
delete from vendas_comissoes where venda_id in (select id from _premium_mov);
delete from vendas where id in (select id from _premium_mov);

-- tira do catálogo, pra ninguém lançar premium em Sistema por engano
delete from venda_products where name ilike '%premium%';

-- recupera o percentual pretendido (ver acima)
update lancamentos set
  comissao_percent  = round(comissao_percent, 2),
  comissao_percent2 = round(comissao_percent2, 2),
  comissao_percent3 = round(comissao_percent3, 2)
where entidade='publicos' and observacoes ilike 'GT %Premium%';

update lancamentos_extra_vendedores e set percent = round(e.percent, 2)
where exists (select 1 from lancamentos l where l.id = e.lancamento_id
               and l.entidade='publicos' and l.observacoes ilike 'GT %Premium%');

-- ============================================================
-- CONFERÊNCIA (o que foi rodado depois, e o resultado)
-- ============================================================
-- lançamentos criados ........... 61
-- valor de contrato ............. R$ 542.041,92  (= backup)
-- linhas de comissão ............ 224
-- comissão pelo percentual ...... R$  81.059,59  (R$ 81.059,43 + 0,16 do arredondamento)
-- vendas premium em Sistema ..... 0
-- produtos premium no catálogo .. 0
-- comissões órfãs ............... 0
-- extras órfãos ................. 0
-- renovações apontando p/ venda inexistente ... 0
