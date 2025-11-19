web: bundle exec rails server -p ${PORT:-4001} -e ${RACK_ENV:-development}
worker: bundle exec sidekiq -e ${RACK_ENV:-development} -C config/sidekiq.yml -r ./config/environment.rb
# worker: bundle exec sidekiq -e $RACK_ENV
