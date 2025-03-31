ARG=

DOCKER_COMPOSE ?= $(shell \
		docker compose version >/dev/null 2>/dev/null \
	&& echo docker compose -f ../dockers/docker-compose.yml \
	|| echo docker-compose -f ../dockers/docker-compose.yml \
	)
bash:
	docker exec -it nobe-cronos-api bash 

# RAILS_ENV=development bundle exec rails server -b 0.0.0.0 -p 3000
start:
	cd ../dockers && make cronos-api

stop:
	cd ../dockers && make stop

stop-force:
	cd ../dockers && make stop-nobe-force

server:
	$(DOCKER_COMPOSE) -p nobe exec nobe-cronos-api bin/rails s -b 0.0.0.0 -p 4001

console:
	$(DOCKER_COMPOSE) -p nobe exec nobe-cronos-api rails console
