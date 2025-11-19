ARG=

DOCKER_COMPOSE ?= $(shell \
		docker compose version >/dev/null 2>/dev/null \
	&& echo docker compose -f ../dockers/docker-compose.yml \
	|| echo docker-compose -f ../dockers/docker-compose.yml \
	)

# Compose local: usa plugin moderno se disponível
LOCAL_COMPOSE ?= $(shell \
		docker compose version >/dev/null 2>/dev/null \
	&& echo docker compose \
	|| echo docker-compose \
)

.PHONY: server console worker coverage test rspec bash debug-server debug-worker reset
bash:
	$(LOCAL_COMPOSE) exec web bash

start:
	$(LOCAL_COMPOSE) up -d db redis web worker

stop:
	$(LOCAL_COMPOSE) stop

stop-force:
	$(LOCAL_COMPOSE) down --remove-orphans

# Reset completo: derruba e remove volumes (perde dados)
reset:
	$(LOCAL_COMPOSE) down -v --remove-orphans

server:
	$(LOCAL_COMPOSE) up -d web
	$(LOCAL_COMPOSE) logs -f web

# Debug server: força Rails em desenvolvimento com TTY
debug-server:
	$(LOCAL_COMPOSE) up -d db redis
	$(LOCAL_COMPOSE) run --rm --service-ports web bash -lc 'bundle check || bundle install && RAILS_ENV=development bundle exec rails s -p 4001 -b 0.0.0.0'

console:
	$(LOCAL_COMPOSE) exec web bash -lc 'bundle check || bundle install && bundle exec rails console'

worker:
	$(LOCAL_COMPOSE) up -d worker
	$(LOCAL_COMPOSE) logs -f worker

# Debug worker: executa Sidekiq com TTY interativo e concorrência 1
debug-worker:
	$(LOCAL_COMPOSE) up -d db redis
	$(LOCAL_COMPOSE) run --rm worker bash -lc 'bundle check || bundle install && bundle exec sidekiq -e development -C config/sidekiq.yml -r ./config/environment.rb'

# Worker local como alias
worker-local: worker

coverage:
	@test -f coverage/index.html || (echo "coverage/index.html não encontrado; rode: $(LOCAL_COMPOSE) exec web bash -lc 'bundle exec rspec'" && exit 1)
	firefox /home/igor/rails_app/cronos-api/coverage/index.html

test:
	$(MAKE) rspec
	$(MAKE) coverage

rspec:
	$(LOCAL_COMPOSE) exec web bash -lc 'bundle exec rspec -f documentation'
