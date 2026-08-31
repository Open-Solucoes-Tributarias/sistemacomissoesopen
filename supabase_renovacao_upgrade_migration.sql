-- ============================================================
-- Migração 22 — upgrade de plano na aba Renovações
-- ============================================================
-- Aplicada no banco como: 20260831XXXXXX renovacao_upgrade_de_plano
--
-- Nem toda conta da carteira renova pelo mesmo valor: às vezes o cliente
-- sai do plano em que estava e migra para um plano bem maior. Isso não é
-- "não renovado" (ele ficou, e a taxa de renovação não pode registrar
-- como perda) e também não é uma renovação comum (o valor mudou, e
-- crescer a conta é venda de verdade — tem que contar no ranking).
--
-- Por isso a linha ganha dois campos:
--   upgrade       → a situação virou "Upgrade" em vez de "Renovado";
--   valor_upgrade → o valor do plano NOVO. O campo valor continua sendo
--                   o da carteira, o que a conta valia antes, para não
--                   perder de vista quanto ela cresceu.
--
-- Ao ir para a aba Sistema, a linha de upgrade nasce com renovacao = false
-- e upgrade = true: é o oposto de uma renovação comum, justamente para
-- entrar no ranking da equipe (a view painel_equipe_totais só descarta o
-- que tem renovacao = true).
alter table renovacoes add column if not exists upgrade boolean not null default false;
alter table renovacoes add column if not exists valor_upgrade numeric;

-- Upgrade implica que o cliente ficou: nunca pode existir upgrade com a
-- situação em "não renovado" ou em aberto.
alter table renovacoes drop constraint if exists renovacoes_upgrade_renovado;
alter table renovacoes add constraint renovacoes_upgrade_renovado
  check (upgrade = false or renovado is true);
