# frozen_string_literal: true

ENV.delete('DATABASE_URL') if ENV['DATABASE_URL'].to_s.strip.empty?
