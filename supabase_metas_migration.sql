-- ============================================================
-- Migração 5: metas viram regras configuráveis
-- ============================================================
-- ANTES: metas era só um número por vendedora/mês (valor_meta),
-- comparado com a comissão que ela ganhou. Não tinha prêmio, não
-- tinha ligação com a aba Bônus, e a régua era igual pra todo mundo.
-- Pior: o próprio bônus entrava na conta da meta que o gerava.
--
-- AGORA: cada meta é um GATILHO DA EMPRESA que premia uma pessoa —
--   "quando a empresa faturar R$ X em <origem> no mês,
--    <fulana> ganha <prêmio>"
-- onde o prêmio é um valor fixo em R$ ou uma % sobre o total
-- faturado (sobre o total inteiro, não sobre o que passou do alvo).
--
-- Exemplos reais que motivaram o formato:
--   • Soraya  → empresa fatura 200 mil em Cursos → 1% do total
--               (faturou 400 mil? o prêmio é 1% de 400 mil = 4.000)
--   • Angela  → mesmo gatilho → R$ 500 fixos
--   • Rios    → mesmo gatilho → R$ 750 fixos
--
-- O prêmio NÃO é lançado sozinho: ao bater, o painel mostra o botão
-- "Lançar bônus de R$ X" e alguém confirma. A linha criada guarda o
-- meta_id, então a mesma meta nunca paga duas vezes.
--
-- ATENÇÃO: recria a tabela metas (o formato antigo não tem como ser
-- convertido — falta origem, alvo e prêmio). Se houver metas
-- cadastradas no formato velho, anote antes de rodar.
-- ============================================================

drop table if exists metas cascade;

create table metas (
  id bigserial primary key,
  ano int not null,
  mes text not null,
  vendedor text not null,                        -- quem recebe o prêmio
  origem text not null                           -- onde o faturamento é medido
    check (origem in ('sistema','consultoria','publicos','cursos','todas')),
  alvo numeric not null check (alvo > 0),        -- ex: 200000
  premio_tipo text not null
    check (premio_tipo in ('fixo','percentual_total')),
  premio_valor numeric not null check (premio_valor > 0), -- 500 (R$) ou 1 (=1%)
  descricao text default '',
  created_at timestamptz not null default now()
);
create index on metas (ano, mes);

-- Liga o bônus à meta que o gerou; o índice único impede pagar duas vezes.
alter table bonus add column if not exists meta_id bigint references metas(id) on delete set null;
create unique index if not exists bonus_meta_unico on bonus (meta_id) where meta_id is not null;

-- Uma meta depende do faturamento da empresa inteira, que conta restrita
-- não pode ver. Por isso configurar e acompanhar é exclusivo de admin.
-- (A vendedora premiada enxerga o resultado normalmente na aba Bônus,
--  porque a linha de bônus tem o nome dela.)
alter table metas enable row level security;
create policy "select admin only" on metas for select to authenticated using (current_user_is_admin());
create policy "admin insert" on metas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on metas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on metas for delete to authenticated using (current_user_is_admin());
