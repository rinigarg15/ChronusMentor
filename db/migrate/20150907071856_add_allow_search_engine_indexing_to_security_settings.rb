class AddAllowSearchEngineIndexingToSecuritySettings< ActiveRecord::Migration[4.2]
  def change
    add_column :security_settings, :allow_search_engine_indexing, :boolean, default: true
  end
end