// Painel de usuários — parte que roda no servidor.
//
// Criar conta, trocar senha e dar acesso exigem a chave de serviço do
// Supabase, que NUNCA pode ir para o navegador: com ela qualquer pessoa
// leria e escreveria o banco inteiro, passando por cima de todas as
// regras de acesso. Por isso essa parte vive aqui, no servidor, e o
// sistema só conversa com ela mandando o token de quem está logado.
//
// Toda chamada é verificada em duas etapas:
//   1. o token é validado de verdade (assinatura), pelo próprio Supabase;
//   2. o usuário por trás do token precisa estar em app_user_access com
//      full_access = true. Só então a ação acontece.
// O id de quem chama NUNCA vem do corpo da requisição — vem do token.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const URL = Deno.env.get('SUPABASE_URL')!;
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function responder(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

function erro(mensagem: string, status = 400) {
  return responder({ erro: mensagem }, status);
}

function emailValido(e: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return erro('Método não permitido.', 405);

  // ---- 1. quem está chamando? ----
  const auth = req.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!token) return erro('Faça login novamente.', 401);

  const comoUsuario = createClient(URL, ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: quem, error: erroToken } = await comoUsuario.auth.getUser();
  if (erroToken || !quem?.user) return erro('Sessão expirada. Entre de novo.', 401);

  // ---- 2. essa pessoa é admin? ----
  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  const { data: acesso } = await admin
    .from('app_user_access')
    .select('full_access')
    .eq('auth_user_id', quem.user.id)
    .maybeSingle();

  if (!acesso?.full_access) {
    return erro('Só quem tem acesso de administrador pode gerenciar usuários.', 403);
  }

  let corpo: any = {};
  try { corpo = await req.json(); } catch { return erro('Requisição inválida.'); }
  const acao = String(corpo?.acao || '');

  // ---- listar ----
  if (acao === 'listar') {
    const { data: contas, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
    if (error) return erro(error.message, 500);
    const { data: acessos } = await admin.from('app_user_access').select('*');
    const porId: Record<string, any> = {};
    (acessos || []).forEach((a: any) => { porId[a.auth_user_id] = a; });

    const lista = (contas?.users || []).map((u: any) => ({
      id: u.id,
      email: u.email,
      criadoEm: u.created_at,
      ultimoAcesso: u.last_sign_in_at,
      admin: !!porId[u.id]?.full_access,
      financeiro: !!porId[u.id]?.financeiro,
      pessoa: porId[u.id]?.person_name || null,
      semAcesso: !porId[u.id],
    })).sort((a: any, b: any) => String(a.email).localeCompare(String(b.email), 'pt-BR'));

    return responder({ usuarios: lista });
  }

  // ---- criar ----
  if (acao === 'criar') {
    const email = String(corpo.email || '').trim().toLowerCase();
    const senha = String(corpo.senha || '');
    const ehAdmin = !!corpo.admin;
    const pessoa = String(corpo.pessoa || '').trim();

    if (!emailValido(email)) return erro('E-mail inválido.');
    if (senha.length < 8) return erro('A senha provisória precisa de pelo menos 8 caracteres.');
    const ehFinanceiro = !ehAdmin && !!corpo.financeiro;
    if (!ehAdmin && !ehFinanceiro && !pessoa) {
      return erro('Para conta restrita, informe o nome como aparece nos lançamentos.');
    }

    const { data: criado, error } = await admin.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
    });
    if (error) {
      const m = String(error.message || '');
      if (/already|registered|exists/i.test(m)) return erro('Já existe uma conta com esse e-mail.');
      return erro(m, 500);
    }

    const { error: erroAcesso } = await admin.from('app_user_access').insert({
      auth_user_id: criado.user.id,
      full_access: ehAdmin,
      financeiro: ehFinanceiro,
      // conta financeira não é de ninguém em particular: vê as notas de
      // todo mundo, então não leva nome de pessoa
      person_name: (ehAdmin || ehFinanceiro) ? null : pessoa,
    });
    if (erroAcesso) {
      // não deixa conta órfã: se o acesso falhou, desfaz a conta
      await admin.auth.admin.deleteUser(criado.user.id);
      return erro('Conta criada mas o acesso falhou; desfiz tudo. ' + erroAcesso.message, 500);
    }

    return responder({ ok: true, id: criado.user.id, email });
  }

  // ---- redefinir senha ----
  if (acao === 'senha') {
    const id = String(corpo.id || '');
    const senha = String(corpo.senha || '');
    if (!id) return erro('Usuário não informado.');
    if (senha.length < 8) return erro('A senha provisória precisa de pelo menos 8 caracteres.');

    const { error } = await admin.auth.admin.updateUserById(id, { password: senha });
    if (error) return erro(error.message, 500);
    return responder({ ok: true });
  }

  // ---- mudar o nível de acesso ----
  if (acao === 'acesso') {
    const id = String(corpo.id || '');
    const ehAdmin = !!corpo.admin;
    const ehFinanceiro = !ehAdmin && !!corpo.financeiro;
    const pessoa = String(corpo.pessoa || '').trim();
    if (!id) return erro('Usuário não informado.');
    if (!ehAdmin && !ehFinanceiro && !pessoa) {
      return erro('Para conta restrita, informe o nome como aparece nos lançamentos.');
    }

    // Não deixa a última conta de administrador virar restrita — senão
    // ninguém mais consegue administrar o sistema.
    if (!ehAdmin) {
      const { count } = await admin
        .from('app_user_access')
        .select('auth_user_id', { count: 'exact', head: true })
        .eq('full_access', true);
      const { data: atual } = await admin
        .from('app_user_access').select('full_access').eq('auth_user_id', id).maybeSingle();
      if (atual?.full_access && (count || 0) <= 1) {
        return erro('Esta é a última conta de administrador. Promova outra pessoa antes de rebaixar esta.');
      }
    }

    const { error } = await admin.from('app_user_access').upsert({
      auth_user_id: id,
      full_access: ehAdmin,
      financeiro: ehFinanceiro,
      person_name: (ehAdmin || ehFinanceiro) ? null : pessoa,
    }, { onConflict: 'auth_user_id' });
    if (error) return erro(error.message, 500);
    return responder({ ok: true });
  }

  return erro('Ação desconhecida.');
});
