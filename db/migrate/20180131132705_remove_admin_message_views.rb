class RemoveAdminMessageViews < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      abstract_view_ids = AbstractView.where(default_view: 20).pluck(:id) # 20 - AbstractView::DefaultType::UNREAD_ADMIN_MESSAGES
      Report::Metric.where(abstract_view_id: abstract_view_ids).destroy_all
      AbstractView.where(id: abstract_view_ids).delete_all(skip_delta_indexing: true)
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      program_ids_to_ignore = AbstractView.where(default_view: 20).pluck(:program_id)
      filter_params_yaml = AbstractView.convert_to_yaml(
        search_filters: {
          search_content: "",
          status: {
            unread: AbstractMessageReceiver::Status::UNREAD.to_s
          },
          sender: "",
          receiver: "",
          date_range: ""
        },
        tab: MessageConstants::Tabs::INBOX,
        include_system_generated: ""
      )

      Program.where.not(id: program_ids_to_ignore).each do |program|
        AbstractView.create!(
          program_id: program.id,
          default_view: 20,
          filter_params: filter_params_yaml,
          title: "feature.abstract_view.admin_message_view.unread_title".translate,
          description: "feature.abstract_view.admin_message_view.unread_description".translate
        )
      end
    end
  end
end