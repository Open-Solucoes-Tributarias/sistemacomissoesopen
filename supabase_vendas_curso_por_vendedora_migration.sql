-- ============================================================
-- Migração 8: um curso é um bolo de faturamento, não uma venda só
-- ============================================================
-- O QUE ESTAVA ERRADO
-- A migração 7 tratou o curso como se tivesse uma vendedora — a coluna
-- "Quem vendeu", com um nome. Só que um lançamento de curso guarda o
-- faturamento TOTAL daquele curso, e esse total vem de várias
-- vendedoras: parte a Rios trouxe, parte a Uilma, parte a Angela.
-- Nenhuma delas vendeu o curso inteiro, então nome nenhum estava certo.
--
-- O QUE MUDA
-- Cada lançamento de curso passa a ter a DIVISÃO do faturamento por
-- vendedora, em reais (tabela lancamento_vendas). O Painel da Equipe
-- soma o que cada uma trouxe.
--
-- A COMISSÃO NÃO MUDA NADA. Ela continua saindo dos campos
-- "Vendedor / % Comissão" do lançamento — a Rios segue com 1% do total
-- de cursos, apareça ela na divisão ou não. São duas leituras
-- diferentes do mesmo lançamento: quem ganha × quem vendeu.
--
-- A aba Sistema fica como está (vendas.vendedor_responsavel): lá cada
-- venda é um contrato de um cliente, feita por uma pessoa.
-- ============================================================

create table if not exists lancamento_vendas (
  id bigserial primary key,
  lancamento_id bigint not null references lancamentos(id) on delete cascade,
  vendedor text not null,
  valor numeric,
  created_at timestamptz not null default now(),
  unique(lancamento_id, vendedor)
);
create index if not exists lancamento_vendas_lanc on lancamento_vendas (lancamento_id);

-- Dado de gestão da equipe inteira: só admin lê e escreve. Cada vendedora
-- vê o próprio total pelo Painel da Equipe, que passa por view agregada.
alter table lancamento_vendas enable row level security;
drop policy if exists "select admin only" on lancamento_vendas;
drop policy if exists "admin insert" on lancamento_vendas;
drop policy if exists "admin update" on lancamento_vendas;
drop policy if exists "admin delete" on lancamento_vendas;
create policy "select admin only" on lancamento_vendas for select to authenticated using (current_user_is_admin());
create policy "admin insert" on lancamento_vendas for insert to authenticated with check (current_user_is_admin());
create policy "admin update" on lancamento_vendas for update to authenticated using (current_user_is_admin()) with check (current_user_is_admin());
create policy "admin delete" on lancamento_vendas for delete to authenticated using (current_user_is_admin());
revoke all on lancamento_vendas from anon;
grant select, insert, update, delete on lancamento_vendas to authenticated;
grant usage, select on sequence lancamento_vendas_id_seq to authenticated;

-- Aproveita o que já tinha sido marcado em "quem vendeu" na migração 7:
-- vira uma linha com o valor cheio do contrato, que dá pra ajustar.
insert into lancamento_vendas (lancamento_id, vendedor, valor)
select id, btrim(vendedor_responsavel), valor_contrato
  from lancamentos
 where entidade = 'cursos'
   and coalesce(btrim(vendedor_responsavel), '') <> ''
on conflict (lancamento_id, vendedor) do nothing;

-- A coluna de nome único não serve para curso. As views que dependiam
-- dela caem junto e voltam logo abaixo.
drop view if exists cursos_sem_responsavel;
drop view if exists painel_equipe_totais;
drop view if exists lancamentos_safe;
alter table lancamentos drop column if exists vendedor_responsavel;

create view lancamentos_safe with (security_barrier = true) as
select
  id, entidade, ano, mes, nome, valor_contrato, tipo, parceiro, participacao,
  forma_pagamento, observacoes,
  case when current_user_is_admin() or name_matches(colaborador, current_user_person_name()) then colaborador else null end as colaborador,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then vendedor  else null end as vendedor,
  case when current_user_is_admin() or name_matches(vendedor,  current_user_person_name()) then comissao_percent  else null end as comissao_percent,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then vendedor2 else null end as vendedor2,
  case when current_user_is_admin() or name_matches(vendedor2, current_user_person_name()) then comissao_percent2 else null end as comissao_percent2,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then vendedor3 else null end as vendedor3,
  case when current_user_is_admin() or name_matches(vendedor3, current_user_person_name()) then comissao_percent3 else null end as comissao_percent3,
  pago, mes_pagamento, parcela_label, created_at, updated_at
from lancamentos
where current_user_is_admin()
   or name_matches(vendedor,  current_user_person_name())
   or name_matches(vendedor2, current_user_person_name())
   or name_matches(vendedor3, current_user_person_name())
   or name_matches(colaborador, current_user_person_name())
   or lancamento_tem_extra_vendedor_meu(id);

alter view lancamentos_safe owner to postgres;
revoke all on lancamentos_safe from anon;
grant select on lancamentos_safe to authenticated;

-- painel_equipe_totais: cursos somam a divisão por vendedora; sistemas
-- seguem pela responsável da venda.
create view painel_equipe_totais with (security_barrier = true) as
select
  btrim(vendedor) as vendedor, ano, mes,
  sum(interacao)        as interacao,
  sum(propostas)        as propostas,
  sum(prospeccao_zero)  as prospeccao_zero,
  sum(prospeccao)       as prospeccao,
  sum(negocios_abertos) as negocios_abertos,
  sum(reunioes)         as reunioes,
  sum(vendas_cursos)    as vendas_cursos,
  sum(vendas_sistemas)  as vendas_sistemas,
  sum(qtd_sistemas)     as qtd_sistemas
from (
  -- 1. indicadores de andamento (digitados)
  select vendedor, ano, mes,
         interacao, propostas, prospeccao_zero, prospeccao, negocios_abertos, reunioes,
         0::numeric as vendas_cursos, 0::numeric as vendas_sistemas, 0::numeric as qtd_sistemas
    from relatorios_equipe

  union all

  -- 2. cursos: quanto cada vendedora trouxe daquele faturamento
  select btrim(lv.vendedor), l.ano, l.mes, 0,0,0,0,0,0, lv.valor, 0, 0
    from lancamento_vendas lv
    join lancamentos l on l.id = lv.lancamento_id
   where l.entidade = 'cursos'
     and coalesce(btrim(lv.vendedor), '') <> ''
     and lv.valor is not null

  union all

  -- 3. sistemas: uma venda, uma vendedora
  select btrim(vd.vendedor_responsavel), vd.ano, vd.mes, 0,0,0,0,0,0, 0, vd.valor, 1
    from vendas vd
   where coalesce(btrim(vd.vendedor_responsavel), '') <> ''
) t
group by btrim(vendedor), ano, mes;

alter view painel_equipe_totais owner to postgres;
revoke all on painel_equipe_totais from anon;
grant select on painel_equipe_totais to authenticated;

-- Cursos cuja divisão ainda não fecha com o valor do contrato.
create or replace view cursos_sem_divisao with (security_barrier = true) as
select l.id, l.ano, l.mes, l.nome, l.valor_contrato,
       coalesce(sum(lv.valor), 0) as dividido,
       coalesce(l.valor_contrato, 0) - coalesce(sum(lv.valor), 0) as falta
  from lancamentos l
  left join lancamento_vendas lv on lv.lancamento_id = l.id
 where l.entidade = 'cursos'
 group by l.id, l.ano, l.mes, l.nome, l.valor_contrato
having coalesce(sum(lv.valor), 0) <> coalesce(l.valor_contrato, 0);

alter view cursos_sem_divisao owner to postgres;
revoke all on cursos_sem_divisao from anon;
grant select on cursos_sem_divisao to authenticated;
