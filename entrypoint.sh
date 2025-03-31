#!/bin/bash
set -e

bundle exec rails db:migrate

# bundle exec sidekiq -C config/sidekiq.yml

# Inicia o servidor Rails
exec bundle exec rails server -b 0.0.0.0 -p 4001