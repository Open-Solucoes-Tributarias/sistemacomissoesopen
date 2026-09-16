-- ============================================================
-- Migração 32 — Renovação sabe PARA ONDE foi lançada
-- ============================================================
--
-- O botão "Lançar no Sistema" sempre criou a venda na aba Sistema, e a
-- renovação guardava o id dela em `venda_id`. Agora plano premium é lançado
-- na aba de Órgãos Públicos, que é OUTRA TABELA (`lancamentos`, não
-- `vendas`) e outro espaço de ids (publicos começa em 100001).
--
-- Sem registrar o destino, `venda_id` vira um número ambíguo: o app não sabe
-- em que tabela procurar. E aí a limpeza de vínculo morto
-- (`soltarRenovacoesOrfas`) não acharia a linha em `vendas`, concluiria que
-- foi excluída e soltaria o vínculo de um lançamento que está vivo em
-- Órgãos Públicos — devolvendo a renovação para a fila e abrindo caminho
-- para lançamento duplicado. Foi justamente essa classe de bug que a
-- migração 28 tratou.
--
-- `venda_entidade` diz onde a linha mora:
--     null ou 'vendas'  → aba Sistema (tabela vendas)
--     'publicos'        → Consultorias e site para Órgãos Públicos (lancamentos)
--
-- Null como padrão mantém as 167 renovações já lançadas apontando para
-- Sistema, sem precisar tocar em nenhuma.
alter table renovacoes add column if not exists venda_entidade text;

alter table renovacoes drop constraint if exists renovacoes_venda_entidade_valida;
alter table renovacoes add constraint renovacoes_venda_entidade_valida
  check (venda_entidade is null or venda_entidade in ('vendas','publicos'));

-- O índice único da migração 28 garantia "uma venda pertence a no máximo uma
-- renovação". Com dois destinos possíveis, o par (entidade, id) é que precisa
-- ser único — senão a venda 5 de Sistema e o lançamento 5 de Órgãos Públicos
-- colidiriam no índice antigo.
drop index if exists renovacoes_venda_id_unico;
create unique index if not exists renovacoes_venda_unico
  on renovacoes(coalesce(venda_entidade,'vendas'), venda_id)
  where venda_id is not null;

-- Conferência:
-- select coalesce(venda_entidade,'vendas') as destino, count(*)
--   from renovacoes where venda_id is not null group by 1;
