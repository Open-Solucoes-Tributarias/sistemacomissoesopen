-- ============================================================
-- Migração 15: valor do contrato nas renovações
-- ============================================================
-- A planilha de renovações que a diretoria já mantinha tem três colunas —
-- empresa, valor e mês —, e o valor é o que diz o tamanho do que está em
-- jogo: quanto foi renovado, quanto se perdeu e quanto ainda está em
-- aberto. Nulo é permitido: a empresa pode entrar na lista antes de
-- alguém confirmar o valor.
--
-- Continua fora dos totais de faturamento e do ranking, como o resto da
-- aba de renovações — é acompanhamento de carteira, não venda nova.
-- ============================================================

alter table renovacoes add column if not exists valor numeric;
