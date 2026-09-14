-- ============================================================
-- Migração 30 — Leads: telefone e e-mail
-- ============================================================
--
-- A migração 29 criou a lista com nome, cargo e empresa. Faltou o que
-- serve para de fato abordar o lead: telefone e e-mail. Sem eles a lista
-- diz quem procurar, mas não como.
--
-- Os dois entram como texto, não como número ou com formato validado:
-- telefone vem com DDD, parêntese, +55, ramal, às vezes dois números na
-- mesma célula; e-mail às vezes vem com espaço ou em caixa alta. Guardar
-- como veio e não recusar nada é melhor do que perder o dado por causa de
-- um formato — o objetivo é ligar para a pessoa, não validar a máscara.
alter table marketing_leads add column if not exists telefone text not null default '';
alter table marketing_leads add column if not exists email    text not null default '';

-- O e-mail é a identidade mais confiável de um lead (dois "Antonio" na
-- mesma empresa existem; dois com o mesmo e-mail, não). É por ele que a
-- reimportação decide se atualiza uma linha existente ou cria outra, então
-- vale um índice.
create index if not exists marketing_leads_email_idx
  on marketing_leads(ano, rede, lower(email)) where email <> '';

-- Conferência:
-- select id, nome, cargo, empresa, telefone, email from marketing_leads order by id;
