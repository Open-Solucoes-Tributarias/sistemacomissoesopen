-- ============================================================
-- Migração 4: correções encontradas na conferência do banco
-- ============================================================
-- Pré-requisito: migrações 1, 2 e 3 já rodadas.
--
-- 1) CORREÇÃO IMPORTANTE — linha de comissão vazia contava como
--    participação na venda.
--    O app grava uma linha em vendas_comissoes para CADA vendedora em
--    CADA venda, quase sempre com valor nulo. A view vendas_safe
--    checava só "existe linha", então bastava alguém ser cadastrada
--    como vendedora para enxergar TODAS as vendas da aba Sistema
--    (cliente, valor do contrato, parceiro) — inclusive as que não
--    tinham nada a ver com ela. Agora exige valor preenchido.
--
-- 2) Função lancamento_matches_person não era mais usada por nenhuma
--    view nem política — removida.
--
-- 3) lancamento_has_extra_vendedor(id, nome) aceitava um nome
--    qualquer, virando um oráculo ("fulano participa do lançamento
--    X?") para quem chamasse /rest/v1/rpc/. Trocada por uma versão
--    que sempre usa o nome de quem está logado.
--
-- 4) As funções auxiliares e as views estavam acessíveis ao papel
--    `anon` (sem login). Acesso revogado.
--
-- 5) name_matches sem search_path fixo (aviso do linter do Supabase).
-- ============================================================

-- (5) search_path fixo
create or replace function public.name_matches(a text, b text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select a is not null and b is not null and btrim(a) <> '' and lower(btrim(a)) = lower(btrim(b));
$$;

-- (3) versão que só sabe responder sobre a própria pessoa
create or replace function public.lancamento_tem_extra_vendedor_meu(lanc_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from lancamentos_extra_vendedores ev
    where ev.lancamento_id = lanc_id
      and name_matches(ev.vendedor, current_user_person_name())
  );
$$;
revoke all on function public.lancamento_tem_extra_vendedor_meu(bigint) from public, anon;
grant execute on function public.lancamento_tem_extra_vendedor_meu(bigint) to authenticated;

-- lancamentos_safe passa a usar a função nova
create or replace view lancamentos_safe with (security_barrier = true) as
select
  id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then vendedor          else null end as vendedor,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then comissao_percent  else null end as comissao_percent,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then vendedor2         else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then comissao_percent2 else null end as comissao_percent2,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then vendedor3         else null end as vendedor3,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then comissao_percent3 else null end as comissao_percent3,
  pago, mes_pagamento, parcela_label, created_at, updated_at
from lancamentos
where current_user_is_admin()
   or name_matches(vendedor,  current_user_person_name())
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or lancamento_tem_extra_vendedor_meu(id);

-- (1) a correção principal: `vc.valor is not null`
create or replace view vendas_safe with (security_barrier = true) as
select
  id, ano, mes, cliente, venda, valor, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor2,   current_user_person_name()) then vendedor2   else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor3,   current_user_person_name()) then vendedor3   else null end as vendedor3,
  pago, mes_pagamento, parcela_label, created_at, updated_at
from vendas
where current_user_is_admin()
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or exists (
     select 1 from vendas_comissoes vc join sellers s on s.key = vc.seller_key
     where vc.venda_id = vendas.id
       and vc.valor is not null
       and name_matches(s.label, current_user_person_name())
   );

-- (2) função órfã
drop function if exists public.lancamento_matches_person(bigint, text);
drop function if exists public.lancamento_has_extra_vendedor(bigint, text);

-- (4) nada disso deve ser alcançável sem login
revoke execute on function public.current_user_is_admin() from anon;
revoke execute on function public.current_user_person_name() from anon;
revoke execute on function public.name_matches(text,text) from anon;
revoke all on lancamentos_safe, lancamentos_extra_vendedores_safe, vendas_safe from anon;

-- `authenticated` precisa destas três: são avaliadas dentro das políticas
-- de RLS, no contexto de quem está consultando.
grant execute on function public.current_user_is_admin() to authenticated;
grant execute on function public.current_user_person_name() to authenticated;
grant execute on function public.name_matches(text,text) to authenticated;
grant select on lancamentos_safe, lancamentos_extra_vendedores_safe, vendas_safe to authenticated;

-- ============================================================
-- Sobre os alertas que o linter do Supabase ainda mostra
-- ------------------------------------------------------------
-- • "Security Definer View" (3x): é o mecanismo, não um defeito. As
--   views precisam rodar como dono do banco justamente para poderem
--   mascarar coluna a coluna; o filtro de quem vê o quê está dentro
--   delas, e a leitura direta das tabelas base é exclusiva de admin.
-- • "Signed-In Users Can Execute SECURITY DEFINER Function" (3x): as
--   três funções só respondem sobre a própria pessoa logada, e são
--   necessárias porque as políticas de RLS as avaliam no contexto de
--   quem consulta.
-- • "Leaked Password Protection Disabled": ative no painel, em
--   Authentication → Policies (não dá pra ligar por SQL).
-- ============================================================
