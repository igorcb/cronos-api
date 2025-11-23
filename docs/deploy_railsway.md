# Deploy via GitHub Actions (Railsway)

## Visão Geral

- Este documento descreve como configurar e operar deploy para produção usando GitHub Actions com Railsway.
- O pipeline possui três jobs: `test`, `lint` e `deploy`. O `deploy` só executa após sucesso dos anteriores.

## Pré‑requisitos

- Repositório com workflow `.github/workflows/rubyonrails.yml` já configurado.
- Ruby no CI: `3.2.2` via `ruby/setup-ruby@v1`.
- Docker local pode usar `3.3.x`; o `Gemfile` aceita `ruby '>= 3.2.2'`.
- Banco PostgreSQL e Redis disponíveis em produção (configurados no Railsway).

## Secrets no GitHub

- `RAILS_MASTER_KEY`: chave do Rails (não commitar em código).
- `RAILSWAY_API_KEY`: chave de API do Railsway.
- `RAILSWAY_APP_ID`: identificador do app no Railsway.
- `RAILSWAY_DEPLOY_CMD`: comando de deploy fornecido pelo Railsway.
- Opcional para testes no CI:
  - `CI_DATABASE_URL`, `CI_PGUSER`, `CI_PGPASSWORD` (se preparar DB remoto no CI).

## Variáveis de Ambiente

- Criar `.env.example` com variáveis esperadas pelo app, sem valores reais:
  - `DATABASE_URL`
  - `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` (se for usar cliente psql)
  - `REDIS_URL`
  - `RAILS_MASTER_KEY`
  - `UPLOAD_SYNC`

## Workflow (rubyonrails.yml)

- Job `test`:
  - Roda em `ubuntu-22.04`, sobe serviços `postgres` e `redis`.
  - Instala Ruby `3.2.2` e gems com cache.
  - Prepara o banco (`rails db:create db:migrate`).
  - Executa `bundle exec rspec`.
- Job `lint`:
  - Instala Ruby `3.2.2`.
  - `bundle audit --update`, `brakeman -w2`, `rubocop --parallel`.
- Job `deploy`:
  - Depende de `test` e `lint`.
  - Executa `RAILSWAY_DEPLOY_CMD` com `RAILSWAY_API_KEY`, `RAILSWAY_APP_ID`, `RAILS_MASTER_KEY`.

## Migrações e Restart

- Garanta que o `RAILSWAY_DEPLOY_CMD` inclua migrações (`rails db:migrate`) e restart da aplicação.
- Caso não inclua, adicionar passos complementares no próprio comando do Railsway.

## Smoke Check pós‑deploy

- Validar aplicação com uma requisição ao endpoint raiz (`GET /`) verificando retorno `{"message":"Server is running!!!"}`.
- Pode ser feito dentro do `RAILSWAY_DEPLOY_CMD` ou via job adicional.

## Rollback

- Definir procedimento: redeploy do commit anterior ou comando específico do Railsway.
- Em migrações destrutivas, planejar passos para reversão (`rails db:rollback`) conforme impacto.

## Convenções de Segurança

- Nunca commitar `.env` nem segredos.
- Usar somente `RAILS_MASTER_KEY` e chaves em `Secrets` do GitHub.
- Brakeman configurado para relatório com nível de confiança 2; ajustar para `-w3 --exit-on-warn` se desejar maior rigor.

## Execução

1. Configure os `Secrets` acima no repositório.
2. Garanta que `RAILSWAY_DEPLOY_CMD` está válido e idempotente.
3. Faça `push` na branch `main`.
4. Acompanhe os jobs `test`, `lint` e `deploy` no GitHub Actions.
5. Valide o smoke check e monitore logs em produção.

## Troubleshooting

- Erro Ruby no CI: usar `ruby/setup-ruby@v1` com `ruby-version: '3.2.2'`.
- Falha no Brakeman: ajustar flags ou corrigir avisos; relatório em `tmp/brakeman.json` no ambiente Docker.
- Migrações demoradas: considere janela de manutenção e `LOCK TIMEOUT`/`statement timeout` ajustados no DB.
