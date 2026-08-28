# admin-usuarios

Função que roda **no servidor** (Supabase Edge Function) e atende ao painel
"Usuários e Acessos" do sistema.

## Por que existe

Criar conta e trocar senha exigem a **chave de serviço** do Supabase. Essa
chave passa por cima de todas as regras de acesso do banco: com ela, qualquer
pessoa lê e escreve tudo. Por isso ela **nunca** pode ficar no `index.html` —
qualquer um abriria o código-fonte da página e a copiaria.

A função resolve isso: a chave fica só aqui, no servidor. O navegador manda
apenas o token de quem está logado.

## Como ela se protege

Toda chamada passa por duas conferências, nesta ordem:

1. **O token é validado de verdade** — assinatura conferida pelo próprio
   Supabase (`auth.getUser`). Token forjado ou expirado para em 401.
2. **A pessoa por trás do token precisa ser admin** — busca em
   `app_user_access` com a chave de serviço e exige `full_access = true`.
   Quem não é admin para em 403.

O id de quem chama **nunca** vem do corpo da requisição: vem do token
verificado. Assim não adianta alguém mandar o id de outra pessoa.

`verify_jwt` está desligado no gateway de propósito — a função faz a
verificação por conta própria (e mais completa, porque também checa se é
admin), e assim a requisição de CORS (OPTIONS) não é barrada antes de chegar.

## Ações

| Ação | O que faz |
|---|---|
| `listar` | devolve as contas com nível de acesso e último login |
| `criar` | cria a conta já confirmada e registra o acesso |
| `senha` | define uma senha provisória nova |
| `acesso` | muda entre admin e restrita, e o nome nos lançamentos |

Duas travas de segurança embutidas:

- Se a conta for criada mas o registro de acesso falhar, a função **desfaz a
  conta** — não deixa usuário órfão, que conseguiria logar sem estar em
  `app_user_access`.
- Não deixa rebaixar a **última conta de administrador**, senão ninguém mais
  conseguiria administrar o sistema.

## Publicar de novo

Pelo painel do Supabase (Edge Functions) ou pela CLI:

```bash
supabase functions deploy admin-usuarios --no-verify-jwt
```

O código-fonte publicado está no painel do Supabase, em
**Edge Functions → admin-usuarios**.
