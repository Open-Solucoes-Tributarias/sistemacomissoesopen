-- ============================================================
-- Migração 26 — Marketing: indicadores configuráveis + RD Station
-- ============================================================
-- Aplicada no banco como: marketing_indicadores
--
-- A migração 24 tinha 3 números fixos por rede (seguidores/alcance/
-- interações), iguais para todo mundo. A Soraya pediu métricas
-- diferentes por plataforma (o YouTube tem "Receita estimada", o
-- Instagram tem "Visitas", o RD Station nem se parece com uma rede
-- social) e o direito de incluir e retirar indicador sem precisar
-- pedir migração de banco toda vez.
--
-- Solução: os valores de cada lançamento viram um jsonb livre
-- (chave do indicador → número ou texto), e uma tabela separada
-- guarda QUAIS indicadores existem por rede — é ela que a tela lê
-- pra montar os cartões e as colunas da tabela, e é nela que o botão
-- "editar indicadores" mexe.

-- ---- 1) marketing_metricas: sai o fixo, entra o jsonb ----
alter table marketing_metricas add column if not exists valores jsonb not null default '{}'::jsonb;

-- Backfill: cada rede usava as 3 colunas fixas com um significado
-- próprio (ex.: em Instagram "alcance" era Contas alcançadas, em
-- YouTube "alcance" era Visualizações). Preserva isso migrando pra
-- chaves com nome que já bate com os indicadores novos daquela rede.
update marketing_metricas set valores =
  case rede
    when 'instagram'   then jsonb_strip_nulls(jsonb_build_object('seguidores', seguidores, 'alcance', alcance, 'interacoes', interacoes))
    when 'youtube'     then jsonb_strip_nulls(jsonb_build_object('inscritos', seguidores, 'visualizacoes', alcance, 'interacoes', interacoes))
    when 'linkedin'    then jsonb_strip_nulls(jsonb_build_object('seguidores', seguidores, 'impressoes', alcance, 'interacoes', interacoes))
    when 'tiktok'      then jsonb_strip_nulls(jsonb_build_object('seguidores', seguidores, 'visualizacoes', alcance, 'interacoes', interacoes))
    when 'podtributar' then jsonb_strip_nulls(jsonb_build_object('ouvintes', seguidores, 'reproducoes', alcance, 'interacoes', interacoes))
    else '{}'::jsonb
  end
where valores = '{}'::jsonb;

alter table marketing_metricas drop column if exists seguidores;
alter table marketing_metricas drop column if exists alcance;
alter table marketing_metricas drop column if exists interacoes;

alter table marketing_metricas drop constraint if exists marketing_metricas_rede_check;
alter table marketing_metricas add constraint marketing_metricas_rede_check
  check (rede in ('instagram','youtube','linkedin','tiktok','podtributar','rdstation'));

-- ---- 2) marketing_indicadores: catálogo de indicadores por rede ----
create table if not exists marketing_indicadores (
  rede   text not null check (rede in ('instagram','youtube','linkedin','tiktok','podtributar','rdstation')),
  chave  text not null,
  rotulo text not null,
  tipo   text not null default 'numero' check (tipo in ('numero','texto')),
  moeda  boolean not null default false,
  ordem  int not null default 0,
  primary key (rede, chave)
);

alter table marketing_indicadores enable row level security;

drop policy if exists "select any" on marketing_indicadores;
create policy "select any" on marketing_indicadores for select to authenticated using (true);

drop policy if exists "insert admin" on marketing_indicadores;
create policy "insert admin" on marketing_indicadores for insert to authenticated
  with check (current_user_is_admin());

drop policy if exists "update admin" on marketing_indicadores;
create policy "update admin" on marketing_indicadores for update to authenticated
  using (current_user_is_admin());

drop policy if exists "delete admin" on marketing_indicadores;
create policy "delete admin" on marketing_indicadores for delete to authenticated
  using (current_user_is_admin());

revoke all on marketing_indicadores from anon;
grant select on marketing_indicadores to authenticated;
grant insert, update, delete on marketing_indicadores to authenticated;

-- Semente: os indicadores que já existiam continuam (pra não sumir com
-- histórico), mais os que a Soraya pediu na tela de referência (imagem
-- do PLATAFORMA × MÉTRICA), inclusive o RD Station, que é indicador
-- novo do zero.
insert into marketing_indicadores (rede, chave, rotulo, tipo, moeda, ordem) values
  ('instagram','alcance','Contas alcançadas','numero',false,1),
  ('instagram','impressoes','Impressões','numero',false,2),
  ('instagram','seguidores','Seguidores','numero',false,3),
  ('instagram','visitas','Visitas','numero',false,4),
  ('instagram','interacoes','Interações','numero',false,5),

  ('youtube','visualizacoes','Visualizações','numero',false,1),
  ('youtube','impressoes','Total de impressões','numero',false,2),
  ('youtube','inscritos','Novos inscritos','numero',false,3),
  ('youtube','receita','Receita estimada','numero',true,4),
  ('youtube','horas_exibidas','Horas exibidas','numero',false,5),
  ('youtube','video_popular','Vídeo popular','texto',false,6),
  ('youtube','interacoes','Interações','numero',false,7),

  ('linkedin','seguidores','Seguidores','numero',false,1),
  ('linkedin','impressoes','Impressões','numero',false,2),
  ('linkedin','interacoes','Interações','numero',false,3),

  ('tiktok','visualizacoes','Visualizações','numero',false,1),
  ('tiktok','visitas','Visitas','numero',false,2),
  ('tiktok','seguidores','Seguidores','numero',false,3),
  ('tiktok','espectadores','Total de espectadores','numero',false,4),
  ('tiktok','novos_espectadores','Novos espectadores','numero',false,5),
  ('tiktok','compartilhamentos','Compartilhamentos','numero',false,6),
  ('tiktok','interacoes','Interações','numero',false,7),

  ('podtributar','ouvintes','Ouvintes','numero',false,1),
  ('podtributar','reproducoes','Reproduções','numero',false,2),
  ('podtributar','interacoes','Interações','numero',false,3),

  ('rdstation','busca_organica','Busca orgânica','numero',false,1),
  ('rdstation','youtube_ref','YouTube','numero',false,2),
  ('rdstation','sites','Sites (Foco/Open)','numero',false,3),
  ('rdstation','conversoes','Conversões','numero',false,4),
  ('rdstation','visitas','Visitas','numero',false,5)
on conflict (rede, chave) do nothing;
