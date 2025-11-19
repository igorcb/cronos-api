FROM ruby:3.3.10

RUN apt-get update -qq && apt-get install -y \
  build-essential apt-utils libpq-dev \
  nodejs postgresql-client vim imagemagick libvips-tools locales

RUN echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen pt_BR.UTF-8 && \
  /usr/sbin/update-locale LANG=pt_BR.UTF-8

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install

COPY . /app/

# Cria o entrypoint diretamente
RUN echo '#!/bin/bash' > /entrypoint.sh && \
  echo 'set -e' >> /entrypoint.sh && \
  echo 'rm -f tmp/pids/server.pid' >> /entrypoint.sh && \
  echo 'bundle check || bundle install' >> /entrypoint.sh && \
  echo 'exec "$@"' >> /entrypoint.sh && \
  chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bundle", "exec", "rails", "s", "-p", "4001", "-b", "0.0.0.0"]