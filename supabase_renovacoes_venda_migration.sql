-- ============================================================
-- Migração 16: ligação entre a renovação e a venda que ela gera
-- ============================================================
-- A renovação confirmada é faturamento do mês e entra na lista de
-- comissões da aba Sistema como qualquer outra venda. Quando isso
-- acontece, a linha da renovação guarda o id da venda criada.
--
-- É o que garante que a mesma renovação nunca seja lançada duas vezes —
-- inclusive depois de recarregar a página — e o que permite ir da
-- renovação direto para a venda correspondente.
--
-- Sem chave estrangeira de propósito: se a venda for excluída na aba
-- Sistema, a renovação continua existindo (com o vínculo apontando para
-- nada), em vez de ser apagada junto. A tela avisa quando isso acontece.
-- ============================================================

alter table renovacoes add column if not exists venda_id bigint;
create index if not exists renovacoes_venda_id on renovacoes (venda_id);
