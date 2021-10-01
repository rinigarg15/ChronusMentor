class RefactorConnectionViewFilters< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        ConnectionView.find_each do |view|
          filter_params_hash = view.filter_params_hash
          if filter_params_hash && filter_params_hash[:sphinx_filter_hash]
            search_filter_key = filter_params_hash.delete(:sphinx_filter_hash).to_s
            filter_params_hash[:search_filter_key] = get_mapped_search_filter(search_filter_key)

            raise "Mapping for search filter hash is not present for view id: #{view.id}" if filter_params_hash[:search_filter_key].blank?

            view.update_attributes!(filter_params: AbstractView.convert_to_yaml(filter_params_hash))
          end
        end
      end
    end
  end

  def down
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        ConnectionView.find_each do |view|
          filter_params_hash = view.filter_params_hash
          if filter_params_hash && filter_params_hash[:search_filter_key]
            search_filter_key = filter_params_hash.delete(:search_filter_key).to_i
            filter_params_hash[:sphinx_filter_hash] = get_inverted_map_search_filter(search_filter_key)

            raise "Mapping for search filter hash is not present for view id: #{view.id}" if filter_params_hash[:sphinx_filter_hash].blank?

            view.update_attributes!(filter_params: AbstractView.convert_to_yaml(filter_params_hash))
          end
        end
      end
    end
  end

  private
  def get_mapped_search_filter(filter_key)
    {
      {"with" => {"status_filter" => true}, "retry_stale" => true, "select" => "*, IF((group_not_started=1),1,0) AS status_filter"}.to_s => AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING,
      {"with" => {"status_filter" => true, "with_overdue_tasks" => true}, "retry_stale" => true, "select" => "*, IF((group_started_active=1),1,0) AS status_filter"}.to_s => AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS,
      {"with" => {"status_filter" => true}, "retry_stale" => true, "select" => "*, IF((group_started_inactive=1),1,0) AS status_filter"}.to_s => AbstractView::DefaultType::INACTIVE_CONNECTIONS
    }[filter_key]
  end

  def get_inverted_map_search_filter(filter_key)
    {
      AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING => {"with" => {"status_filter" => true}, "retry_stale" => true, "select" => "*, IF((group_not_started=1),1,0) AS status_filter"},
      AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS => {"with" => {"status_filter" => true, "with_overdue_tasks" => true}, "retry_stale" => true, "select" => "*, IF((group_started_active=1),1,0) AS status_filter"},
      AbstractView::DefaultType::INACTIVE_CONNECTIONS => {"with" => {"status_filter" => true}, "retry_stale" => true, "select" => "*, IF((group_started_inactive=1),1,0) AS status_filter"}
    }[filter_key]
  end

end
