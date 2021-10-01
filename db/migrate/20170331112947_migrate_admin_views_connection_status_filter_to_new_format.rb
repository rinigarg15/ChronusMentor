class MigrateAdminViewsConnectionStatusFilterToNewFormat< ActiveRecord::Migration[4.2]
  def up
    AdminView.find_each do |admin_view|
      filter_params = admin_view.filter_params_hash
      if filter_params[:connection_status].present?
        changed = false
        advanced_filters_added = false
        if filter_params[:connection_status][:status].present?
          if [UsersIndexFilters::Values::CONNECTED, UsersIndexFilters::Values::UNCONNECTED, UsersIndexFilters::Values::NEVERCONNECTED].include?(filter_params[:connection_status][:status])
            filter_params[:connection_status][:status_filters] = {}
            filter_params[:connection_status][:status_filters][:status_filter_1] = { AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS }
            advanced_filters_added = true
            case filter_params[:connection_status][:status]
            when UsersIndexFilters::Values::CONNECTED
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::TYPE] = AdminView::ConnectionStatusTypeKey::ONGOING
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::OPERATOR] = AdminView::ConnectionStatusOperatorKey::GREATER_THAN
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE] = "0"
            when UsersIndexFilters::Values::UNCONNECTED
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::TYPE] = AdminView::ConnectionStatusTypeKey::ONGOING
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::OPERATOR] = AdminView::ConnectionStatusOperatorKey::LESS_THAN
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE] = "1"
            when UsersIndexFilters::Values::NEVERCONNECTED
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::TYPE] = AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::OPERATOR] = AdminView::ConnectionStatusOperatorKey::LESS_THAN
              filter_params[:connection_status][:status_filters][:status_filter_1][AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE] = "1"
            end
          end
          filter_params[:connection_status].delete(:status)
          changed = true
        end
        if filter_params[:connection_status][:draft_status].present?
          draft_status = filter_params[:connection_status][:draft_status].to_i
          if [AdminView::DraftConnectionStatus::WITH_DRAFTS, AdminView::DraftConnectionStatus::WITHOUT_DRAFTS].include?(draft_status)
            status_filter_key = advanced_filters_added ? :status_filter_2 : :status_filter_1
            filter_params[:connection_status][:status_filters] = {} unless advanced_filters_added
            filter_params[:connection_status][:status_filters][status_filter_key] = { AdminView::ConnectionStatusFilterObjectKey::CATEGORY => (advanced_filters_added ? "" : AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS) }
            case draft_status
            when AdminView::DraftConnectionStatus::WITH_DRAFTS
              filter_params[:connection_status][:status_filters][status_filter_key][AdminView::ConnectionStatusFilterObjectKey::TYPE] = AdminView::ConnectionStatusTypeKey::DRAFTED
              filter_params[:connection_status][:status_filters][status_filter_key][AdminView::ConnectionStatusFilterObjectKey::OPERATOR] = AdminView::ConnectionStatusOperatorKey::GREATER_THAN
              filter_params[:connection_status][:status_filters][status_filter_key][AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE] = "0"
            when AdminView::DraftConnectionStatus::WITHOUT_DRAFTS
              filter_params[:connection_status][:status_filters][status_filter_key][AdminView::ConnectionStatusFilterObjectKey::TYPE] = AdminView::ConnectionStatusTypeKey::DRAFTED
              filter_params[:connection_status][:status_filters][status_filter_key][AdminView::ConnectionStatusFilterObjectKey::OPERATOR] = AdminView::ConnectionStatusOperatorKey::LESS_THAN
              filter_params[:connection_status][:status_filters][status_filter_key][AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE] = "1"
            end
          end
          filter_params[:connection_status].delete(:draft_status)
          changed = true
        end
        if changed
          admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
          admin_view.save!
        end
      end
    end
  end

  def down
    # do nothing
  end
end
