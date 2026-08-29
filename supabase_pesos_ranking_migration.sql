-- ============================================================
-- Migração 13: pesos do ranking da equipe
-- ============================================================
-- O ranking contava quantos indicadores cada pessoa liderava. Isso tratava
-- "interação" e "venda de sistema" como equivalentes — e não são — e ainda
-- ignorava a margem: liderar por 1 valia igual a liderar pelo dobro. Na
-- prática, dava para ser campeã do ano vencendo os indicadores de menor
-- importância.
--
-- Agora cada indicador tem um PESO, e a pontuação de cada pessoa é a fatia
-- que ela teve do total da equipe naquele indicador, multiplicada pelo
-- peso. Como as fatias de um indicador somam 100%, os pontos de todo mundo
-- somam 100 — o placar lê-se direto.
--
-- Os pesos ficam aqui, não no código, porque são decisão de quem dirige a
-- área e mudam com a estratégia. Peso 0 tira o indicador da pontuação sem
-- tirá-lo do painel.
--
-- Leitura liberada para toda conta logada (o ranking é o placar da equipe);
-- escrita só para admin.
-- ============================================================

create table if not exists painel_pesos (
  metrica text primary key,
  peso int not null default 1 check (peso between 0 and 5),
  updated_at timestamptz not null default now()
);

alter table painel_pesos enable row level security;

drop policy if exists "todos leem" on painel_pesos;
drop policy if exists "admin insert" on painel_pesos;
drop policy if exists "admin update" on painel_pesos;
drop policy if exists "admin delete" on painel_pesos;
create policy "todos leem" on painel_pesos for select to authenticated using (true);
create policy "admin insert" on painel_pesos for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on painel_pesos for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on painel_pesos for delete to authenticated using (current_user_is_admin());

revoke all on painel_pesos from anon;
grant select, insert, update, delete on painel_pesos to authenticated;

-- Pesos definidos pela diretoria comercial: o que vira contrato vale 5;
-- o que é caminho para o contrato vale 2; interação, o mais fácil de
-- inflar, vale 1.
insert into painel_pesos (metrica, peso) values
  ('reunioes', 5), ('vendasCursos', 5), ('vendasSistemas', 5), ('qtdSistemas', 5),
  ('propostas', 2), ('prospeccaoZero', 2), ('prospeccao', 2), ('negociosAbertos', 2),
  ('interacao', 1)
on conflict (metrica) do update set peso = excluded.peso, updated_at = now();
