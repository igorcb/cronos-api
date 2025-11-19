#!/bin/bash
set -e

# Remove o server.pid se existir
if [ -f tmp/pids/server.pid ]; then
  rm -f tmp/pids/server.pid
fi

# Instala as gems se necessário
bundle check || bundle install

# Executa o comando principal
exec "$@"