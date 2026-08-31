-- ============================================================
-- Migração 23 — "nota emitida": o visto do financeiro
-- ============================================================
-- Aplicada no banco em duas partes:
--   nota_emitida
--   safe_views_nota_emitida
--
-- Quem confere faturamento precisa marcar o que já foi emitido, senão a
-- lista de notas do mês não diz nada sobre o trabalho dela — só sobre o
-- que foi vendido.
--
-- O visto mora nas duas tabelas que guardam nota (vendas e lancamentos),
-- e não numa tabela à parte: é um atributo da nota, e assim ele acompanha
-- a linha se ela for excluída ou reaproveitada.
alter table vendas       add column if not exists nota_emitida boolean not null default false;
alter table vendas       add column if not exists nota_emitida_em timestamptz;
alter table lancamentos  add column if not exists nota_emitida boolean not null default false;
alter table lancamentos  add column if not exists nota_emitida_em timestamptz;

-- ------------------------------------------------------------
-- A única porta de escrita para o financeiro
-- ------------------------------------------------------------
-- A conta financeira é de leitura: não tem update em vendas nem em
-- lancamentos, e não pode ganhar — uma política de update em cima da
-- tabela inteira deixaria essa conta mexer em QUALQUER coluna pela API,
-- inclusive no valor do contrato. RLS filtra linha, não coluna.
--
-- Então a escrita passa por esta função, que é a porta estreita: confere
-- quem está chamando e mexe em exatamente uma coluna. Quem não é admin
-- nem financeiro não entra.
create or replace function public.marcar_nota_emitida(
  p_tabela text, p_id bigint, p_emitida boolean
) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare quando timestamptz;
begin
  if not (current_user_is_admin() or current_user_is_financeiro()) then
    raise exception 'Sem permissão para marcar nota emitida.';
  end if;
  quando := case when p_emitida then now() else null end;
  if p_tabela = 'vendas' then
    update vendas set nota_emitida = p_emitida, nota_emitida_em = quando where id = p_id;
  elsif p_tabela = 'lancamentos' then
    update lancamentos set nota_emitida = p_emitida, nota_emitida_em = quando where id = p_id;
  else
    raise exception 'Tabela inválida.';
  end if;
  return quando;
end; $$;
revoke all on function public.marcar_nota_emitida(text, bigint, boolean) from public, anon;
grant execute on function public.marcar_nota_emitida(text, bigint, boolean) to authenticated;

-- ------------------------------------------------------------
-- As views _safe precisam devolver as colunas novas
-- ------------------------------------------------------------
-- Regra do projeto: coluna nova em vendas/lancamentos entra TAMBÉM na view
-- _safe correspondente. O sistema lê pelas views, então sem isto o visto
-- seria gravado e nunca lido de volta.
--
-- O visto não é remuneração: todo mundo que já enxerga a linha enxerga
-- também se a nota dela foi emitida. Por isso as duas colunas saem sem
-- máscara, no fim da lista (create or replace view só aceita colunas
-- novas no fim).
--
-- As definições completas das duas views estão em
-- supabase_acesso_financeiro_migration.sql; aqui só acrescentam-se
-- "nota_emitida, nota_emitida_em" ao fim de cada select, mantendo todo o
-- resto igual. Ao recriar o banco do zero, rode aquele arquivo primeiro e
-- depois este.
