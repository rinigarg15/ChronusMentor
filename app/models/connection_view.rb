# == Schema Information
#
# Table name: admin_views
#
#  id            :integer          not null, primary key
#  title         :string(255)
#  program_id    :integer          not null
#  filter_params :text(16777215)
#  default_view  :integer
#  created_at    :datetime
#  updated_at    :datetime
#  description   :text(16777215)
#  type          :string(255)      default("AdminView")
#  favourite     :boolean          default(FALSE)
#  favourited_at :datetime
#  role_id       :integer
#

class ConnectionView < AbstractView
  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    CONNECTIONS_NEVER_GOT_GOING = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.connection_view.connections_never_got_going_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.connection_view.connections_never_got_going_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({
            params: {sub_filter: {not_started: GroupsController::StatusFilters::NOT_STARTED}, tab: Group::Status::ACTIVE},
            search_filter_key: AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING
          })
        },
        default_view: -> { AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING }
      }
    }

    ACTIVE_BEHIND_CONNECTIONS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.connection_view.active_behind_connections_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.connection_view.active_behind_connections_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({
            params: {sub_filter: {active: GroupsController::StatusFilters::Code::ACTIVE}, search_filters: {v2_tasks_status: GroupsController::TaskStatusFilter::OVERDUE}, tab: Group::Status::ACTIVE},
            search_filter_key: AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS
          })
        },
        default_view: -> { AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS }
      }
    }

    INACTIVE_CONNECTIONS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.connection_view.inactive_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.connection_view.inactive_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({
            params: {sub_filter: {inactive: GroupsController::StatusFilters::Code::INACTIVE}, tab: Group::Status::ACTIVE},
            search_filter_key: AbstractView::DefaultType::INACTIVE_CONNECTIONS
          })
        },
        default_view: -> { AbstractView::DefaultType::INACTIVE_CONNECTIONS }
      }
    }

    DRAFTED_CONNECTIONS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.connection_view.drafted_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.connection_view.drafted_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({
            params: {tab: Group::Status::DRAFTED},
            search_filter_key: AbstractView::DefaultType::DRAFTED_CONNECTIONS
          })
        },
        default_view: -> { AbstractView::DefaultType::DRAFTED_CONNECTIONS }
      }
    }

    UNSATISFIED_USERS_CONNECTIONS = {} # later, TBD

    class << self
      def all
        [CONNECTIONS_NEVER_GOT_GOING, INACTIVE_CONNECTIONS, ACTIVE_BEHIND_CONNECTIONS, DRAFTED_CONNECTIONS]
      end
    end

    SEARCH_FILTER_KEYS_MAP = {
      AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING => {must_filters: Group.group_not_started },
      AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS => {must_filters: { has_overdue_tasks: true }.merge(Group.group_started_active) },
      AbstractView::DefaultType::INACTIVE_CONNECTIONS => { must_filters: Group.group_started_inactive },
      AbstractView::DefaultType::DRAFTED_CONNECTIONS => { must_filters: Group.group_draft }
    }
  end

  def count(alert=nil)
    search_filters_hash = DefaultViews::SEARCH_FILTER_KEYS_MAP[filter_params_hash[:search_filter_key]]
    search_filters_hash[:must_filters].merge!(program_id: program_id)
    Group.get_filtered_groups_count(search_filters_hash)
  end
end
