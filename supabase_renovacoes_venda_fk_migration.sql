-- Migração 28: renovacoes.venda_id vira referência de verdade
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
--    e em cada caso a venda ficou reivindicada por duas renovações.
--
-- A foreign key com ON DELETE SET NULL resolve o item 1 de forma definitiva e
-- no lugar certo: quem exclui a venda solta a renovação, sem depender de o
-- código do app lembrar de fazer isso. O item 2 é corrigido no app
-- (reservarNextIdVendas), porque o banco não tem como saber que um id
-- reaproveitado é "outra" venda.
--
-- Idempotente: pode rodar mais de uma vez.

-- ---------------------------------------------------------------------------
-- 1. Limpa ponteiros mortos. A FK não é criada enquanto existir venda_id
--    apontando para venda que não existe.
-- ---------------------------------------------------------------------------
update renovacoes r
   set venda_id = null
 where r.venda_id is not null
   and not exists (select 1 from vendas v where v.id = r.venda_id);

-- ---------------------------------------------------------------------------
-- 2. A referência em si.
-- ---------------------------------------------------------------------------
alter table renovacoes drop constraint if exists renovacoes_venda_id_fkey;
alter table renovacoes
  add constraint renovacoes_venda_id_fkey
  foreign key (venda_id) references vendas(id) on delete set null;

-- Busca por venda_id acontece a cada exclusão de venda (a FK precisa varrer
-- renovacoes) e ao montar a fila de lançamento.
create index if not exists renovacoes_venda_id_idx on renovacoes(venda_id);

-- ---------------------------------------------------------------------------
-- 3. Uma venda pertence a no máximo uma renovação.
--    O reuso de id fazia duas renovações reivindicarem a mesma venda, e nada
--    no banco reclamava. Agora reclama — o índice único deixa o estrago
--    aparecer na hora em que for criado, em vez de semanas depois.
--
--    ATENÇÃO: este índice só é criado se os dados já estiverem limpos. Rode
--    a consulta de conferência no fim do arquivo antes; se ela devolver
--    linhas, corrija-as primeiro (ou comente este bloco).
-- ---------------------------------------------------------------------------
create unique index if not exists renovacoes_venda_id_unico
  on renovacoes(venda_id) where venda_id is not null;

-- ---------------------------------------------------------------------------
-- Conferência: renovação cuja venda é de outra empresa, e venda reivindicada
-- por mais de uma renovação. As duas devem voltar vazias.
-- ---------------------------------------------------------------------------
-- select r.id, r.empresa, r.mes, r.ano, v.cliente, v.mes, v.ano
--   from renovacoes r join vendas v on v.id = r.venda_id
--  where upper(trim(v.cliente)) <> upper(trim(r.empresa));
--
-- select venda_id, count(*) from renovacoes
--  where venda_id is not null group by venda_id having count(*) > 1;
