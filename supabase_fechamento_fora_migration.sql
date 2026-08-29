-- ============================================================
-- Migração 12: quem fica de fora do fechamento
-- ============================================================
-- O quadro "Fechamento para a contabilidade" lista todo mundo que teve
-- comissão, bônus ou salário no período. Nem sempre isso é o que vai para
-- a contabilidade: pode haver gente que é paga por fora, nome repetido de
-- um cadastro antigo, ou alguém que só tem Consultoria a receber.
--
-- A lista de exclusões fica em entity_vendors com entidade =
-- 'fechamento_fora' — a mesma tabela das outras listas de pessoas, que já
-- tem leitura liberada para quem está logado e escrita só para admin.
--
-- Guarda-se quem fica de FORA, e não quem fica dentro, de propósito:
-- assim uma pessoa nova aparece na folha sozinha, em vez de sumir calada.
-- Esquecer alguém num relatório de pagamento é bem pior do que ter uma
-- linha a mais para tirar.
-- ============================================================

alter table entity_vendors drop constraint if exists entity_vendors_entidade_check;
alter table entity_vendors add constraint entity_vendors_entidade_check
  check (entidade in ('consultoria','publicos','cursos','painel','painel_contratos','fechamento_fora'));
