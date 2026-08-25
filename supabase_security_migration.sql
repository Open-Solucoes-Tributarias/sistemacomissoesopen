-- ============================================================
-- Migração de segurança: exigir login (Supabase Auth)
-- ============================================================
-- Antes desta migração, todas as tabelas tinham a política
-- "anon full access": qualquer pessoa com a URL do Supabase e a
-- chave pública (anon key) conseguia ler e escrever em todos os
-- dados, sem precisar de login. Essa chave fica embutida no
-- index.html porque é assim que o Supabase funciona (ela é
-- pública por padrão) — quem protege os dados de verdade são as
-- políticas de RLS abaixo.
--
-- Esta migração troca o acesso de "anon" (qualquer um com o link)
-- para "authenticated" (só quem fez login com e-mail/senha). O
-- index.html já foi atualizado para pedir login antes de acessar
-- o sistema e envia o token da pessoa logada em cada requisição.
--
-- !! IMPORTANTE — ORDEM DE EXECUÇÃO !!
-- 1) Rode este script no SQL Editor do Supabase.
-- 2) Crie uma conta para cada pessoa da equipe em
--    Authentication → Users → Add user (no painel do Supabase),
--    ANTES de publicar a nova versão do index.html.
-- 3) Só depois publique/atualize o site.
-- Se pular o passo 2, ninguém consegue mais entrar no sistema
-- até que as contas sejam criadas.
-- ============================================================

-- Remove as políticas antigas, liberadas para a chave anônima
drop policy if exists "anon full access" on sellers;
drop policy if exists "anon full access" on partners;
drop policy if exists "anon full access" on venda_products;
drop policy if exists "anon full access" on entity_vendors;
drop policy if exists "anon full access" on vendas;
drop policy if exists "anon full access" on vendas_comissoes;
drop policy if exists "anon full access" on lancamentos;
drop policy if exists "anon full access" on lancamentos_extra_vendedores;
drop policy if exists "anon full access" on bonus;
drop policy if exists "anon full access" on metas;
drop policy if exists "anon full access" on closed_months;
drop policy if exists "anon full access" on extra_years;

-- Cria as novas políticas, liberadas só para usuários autenticados.
-- O sistema continua sendo de uso compartilhado pela equipe (não há
-- dono por linha), então qualquer pessoa logada pode ler e escrever
-- em qualquer registro — igual ao comportamento de hoje, mas agora
-- exigindo login.
create policy "authenticated full access" on sellers for all to authenticated using (true) with check (true);
create policy "authenticated full access" on partners for all to authenticated using (true) with check (true);
create policy "authenticated full access" on venda_products for all to authenticated using (true) with check (true);
create policy "authenticated full access" on entity_vendors for all to authenticated using (true) with check (true);
create policy "authenticated full access" on vendas for all to authenticated using (true) with check (true);
create policy "authenticated full access" on vendas_comissoes for all to authenticated using (true) with check (true);
create policy "authenticated full access" on lancamentos for all to authenticated using (true) with check (true);
create policy "authenticated full access" on lancamentos_extra_vendedores for all to authenticated using (true) with check (true);
create policy "authenticated full access" on bonus for all to authenticated using (true) with check (true);
create policy "authenticated full access" on metas for all to authenticated using (true) with check (true);
create policy "authenticated full access" on closed_months for all to authenticated using (true) with check (true);
create policy "authenticated full access" on extra_years for all to authenticated using (true) with check (true);

-- Dica: para impedir que qualquer pessoa se auto-cadastre pelo
-- formulário de login (o index.html não expõe cadastro, mas a API
-- do Supabase aceita sign-up por padrão), desative o cadastro
-- público em Authentication → Providers → Email → "Allow new users
-- to sign up" (desmarque a opção). Assim, só quem você cadastrar
-- manualmente em Authentication → Users consegue entrar.
