# frozen_string_literal: true

require_relative 'boot'
require 'logger'
require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_mailbox/engine'
require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ActiveRecord
  class Base
    class << self
      def has_many_inversing=(value); end unless respond_to?(:has_many_inversing=)
      def belongs_to_required_by_default=(value); end unless respond_to?(:belongs_to_required_by_default=)
      def run_commit_callbacks_on_first_saved_instances_in_transaction=(value); end unless respond_to?(:run_commit_callbacks_on_first_saved_instances_in_transaction=)
      def automatic_scope_inversing=(value); end unless respond_to?(:automatic_scope_inversing=)
      def async_query_executor=(value); end unless respond_to?(:async_query_executor=)
      def raise_on_assign_to_wrong_type=(value); end unless respond_to?(:raise_on_assign_to_wrong_type=)
      def strict_loading_by_default=(value); end unless respond_to?(:strict_loading_by_default=)
    end
  end
end

module Cronos
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1
    initializer 'cronos.ensure_ar_encryption', before: 'active_record.set_configs' do
      config.active_record ||= ActiveSupport::OrderedOptions.new
      config.active_record.encryption ||= {}
    end
    

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = false
    config.active_job.queue_adapter = :sidekiq
    config.middleware.use ActionDispatch::Session::CookieStore
  end
end
