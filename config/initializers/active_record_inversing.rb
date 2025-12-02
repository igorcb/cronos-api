# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  base = ActiveRecord::Base
  class << base
    def has_many_inversing=(_); end unless respond_to?(:has_many_inversing=)
    def belongs_to_required_by_default=(_); end unless respond_to?(:belongs_to_required_by_default=)
    def run_commit_callbacks_on_first_saved_instances_in_transaction=(_); end unless respond_to?(:run_commit_callbacks_on_first_saved_instances_in_transaction=)
  end
end
