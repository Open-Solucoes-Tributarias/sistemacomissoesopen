-- Migração 28: renovacoes.venda_id ganha índice único (e por que NÃO ganha
-- foreign key)
--
-- A renovação guarda o id da venda que gerou (renovacoes.venda_id), mas essa
-- coluna era um bigint solto: nenhuma referência, nenhuma regra. Dois
-- estragos vinham daí.
--
-- 1. Venda excluída deixava a renovação apontando para o vazio. Ela ficava
--    presa: mantinha a etiqueta "no Sistema", não voltava para a fila de
--    lançamento e recusava virar upgrade pedindo para excluir uma venda que
--    já não existia.
--
-- 2. Pior: o app calcula o id da venda nova no navegador, como max(ids)+1.
--    Excluir a venda de MAIOR id devolvia aquele número para a fila, e a
--    venda seguinte nascia com ele. A renovação antiga passava então a
--    apontar para uma venda NOVA e sem relação nenhuma — outra empresa,
--    outro mês, outro valor. Aconteceu duas vezes nos dados reais:
--      renovacoes 143 (MP RR, Out/2026)  -> venda 268 (TRE PA,  Set/2027)
--      renovacoes 6   (INPI,  Jan/2026)  -> venda 76  (PRODAP,  Abr/2026)
--    e em cada caso a venda ficou reivindicada por duas renovações. Foi o
--    que fez a renovação do MP RR recusar virar upgrade sem ter saída: a
--    trava perguntava "essa venda existe?", e existia — só não era dela.
--
-- ---------------------------------------------------------------------------
-- POR QUE NÃO HÁ FOREIGN KEY AQUI
--
-- A primeira versão desta migração criava
--     foreign key (venda_id) references vendas(id) on delete set null
-- que resolveria o item 1 no lugar certo. Ela foi aplicada, testada e
-- REVERTIDA, porque quebra a gravação:
--
-- O app grava vendas e renovações em DUAS requisições independentes, cada uma
-- com seu próprio debounce de 450ms e sem transação em comum. No lançamento
-- (confirmarLancarNoSistema), a renovação já sai apontando para a venda nova,
-- e as duas gravações partem quase juntas — mas a de renovações é uma única
-- chamada, enquanto a de vendas escreve ~275 vendas MAIS ~1.900 linhas de
-- vendas_comissoes. A das renovações chega primeiro, a venda ainda não existe
-- no banco, e a FK rejeita: "erro ao salvar" em todo lançamento de renovação,
-- com o vínculo perdido. Pior que o bug que ela evitava.
--
-- Constraint DEFERRABLE não ajuda: cada requisição é sua própria transação, e
-- o check adiado acontece no commit dela.
--
-- Para voltar a FK é preciso primeiro tornar a gravação sequencial — venda
-- confirmada no banco e só então a renovação. Enquanto isso, a garantia de
-- "venda excluída solta a renovação" mora no app (soltarRenovacoesOrfas,
-- chamado em deleteRow e ao terminar a carga), que tem teste.
-- ---------------------------------------------------------------------------
--
-- Idempotente: pode rodar mais de uma vez.

-- 1. Limpa ponteiros mortos deixados antes de a correção existir.
update renovacoes r
   set venda_id = null
 where r.venda_id is not null
   and not exists (select 1 from vendas v where v.id = r.venda_id);

-- 2. Uma venda pertence a no máximo uma renovação.
--    Diferente da FK, este índice não depende de ordem de gravação: ele só
--    proíbe duas renovações compartilharem a mesma venda, o que é verdade em
--    qualquer ordem. É a trava que faz o estrago do reuso de id aparecer na
--    hora em que for criado, em vez de semanas depois.
create unique index if not exists renovacoes_venda_id_unico
  on renovacoes(venda_id) where venda_id is not null;

-- 3. Busca por venda_id acontece ao montar a fila de lançamento.
create index if not exists renovacoes_venda_id_idx on renovacoes(venda_id);

-- ---------------------------------------------------------------------------
-- Conferência: as duas devem voltar vazias.
-- ---------------------------------------------------------------------------
-- -- ponteiro morto
-- select r.id, r.empresa, r.venda_id from renovacoes r
--  where r.venda_id is not null
--    and not exists (select 1 from vendas v where v.id = r.venda_id);
--
-- -- renovação cuja venda é de outra empresa (ignorando acento e pontuação)
-- select r.id, r.empresa, r.mes, r.ano, v.id, v.cliente, v.mes, v.ano
--   from renovacoes r join vendas v on v.id = r.venda_id
--  where regexp_replace(upper(translate(r.empresa,'ÁÀÃÂÉÊÍÓÕÔÚÇ','AAAAEEIOOOUC')),'[^A-Z0-9]','','g')
--     <> regexp_replace(upper(translate(v.cliente,'ÁÀÃÂÉÊÍÓÕÔÚÇ','AAAAEEIOOOUC')),'[^A-Z0-9]','','g');
