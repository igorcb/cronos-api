FROM ruby:3.1.3

RUN apt-get update -qq && apt-get install -y \
  build-essential apt-utils libpq-dev \
  nodejs postgresql-client vim yarn imagemagick libvips-tools locales

RUN echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen pt_BR.UTF-8 && \
  /usr/sbin/update-locale LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

ENV APP_PATH=/app
RUN mkdir -p $APP_PATH
WORKDIR $APP_PATH

COPY Gemfile Gemfile.lock $APP_PATH/
RUN gem install bundler && bundle install 

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

EXPOSE 4001

ENTRYPOINT ["entrypoint.sh"]