# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

# Evita erro do ActiveRecord com DATABASE_URL vazio em ambientes locais
ENV.delete('DATABASE_URL') if ENV['DATABASE_URL'].to_s.strip.empty?

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
