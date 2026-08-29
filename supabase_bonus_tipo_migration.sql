-- ============================================================
-- Migração 11: bônus fixo x bônus variável
-- ============================================================
-- A aba Bônus e Metas misturava duas coisas de natureza diferente:
--   • bônus de valor fechado, que se repete igual todo mês
--     (ex.: "Participação SAAE Volta Redonda — R$ 100");
--   • bônus que muda com o desempenho do mês
--     (ex.: "1% de R$ 441.206,00 em Cursos — R$ 4.412,06").
--
-- A coluna "tipo" separa os dois. Fica NULA por padrão: o bônus pode ser
-- lançado antes de alguém decidir como classificá-lo, e o sistema não
-- deve chutar.
-- ============================================================

alter table bonus add column if not exists tipo text;

-- Backfill do que dá para saber com certeza: o bônus que saiu de uma regra
-- de meta herda o tipo do prêmio daquela regra. Prêmio em R$ fechado é
-- fixo; prêmio em % do faturado varia com o mês, então é variável.
-- Os bônus digitados à mão ficam em branco de propósito.
update bonus b
   set tipo = case when m.premio_tipo = 'fixo' then 'Fixo' else 'Variável' end
  from metas m
 where m.id = b.meta_id
   and b.tipo is null;
