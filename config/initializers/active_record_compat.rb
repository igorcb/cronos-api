ActiveSupport.on_load(:active_record) do
  base = ActiveRecord::Base
  class << base
    def has_many_inversing=(_); end unless respond_to?(:has_many_inversing=)
    def belongs_to_required_by_default=(_); end unless respond_to?(:belongs_to_required_by_default=)
    def run_commit_callbacks_on_first_saved_instances_in_transaction=(_); end unless respond_to?(:run_commit_callbacks_on_first_saved_instances_in_transaction=)
    def automatic_scope_inversing=(_); end unless respond_to?(:automatic_scope_inversing=)
    def async_query_executor=(_); end unless respond_to?(:async_query_executor=)
    def raise_on_assign_to_wrong_type=(_); end unless respond_to?(:raise_on_assign_to_wrong_type=)
    def strict_loading_by_default=(_); end unless respond_to?(:strict_loading_by_default=)
  end
end
