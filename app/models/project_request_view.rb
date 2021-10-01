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

# The filter_params are stored as follows
# { 
#   status: ,
#   project: 
#   requestor:
#   sent: {before: , after:} 
# }
#
class ProjectRequestView < AbstractView

  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    PENDING_PROJECT_REQUESTS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.pending_request_view.pending_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.pending_request_view.pending_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({status: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED]}) },
        default_view: -> { AbstractView::DefaultType::PENDING_PROJECT_REQUESTS }
      }
    }

    class << self
      def all
        [PENDING_PROJECT_REQUESTS]
      end
    end
  end

  def count(alert=nil)
    filter_params = self.get_params_to_service_format
    es_options = { program: self.program, skip_pagination: true }
    ProjectRequest.get_project_requests_search_count(filter_params, es_options)
  end

  def get_params_to_service_format
    filter_params = self.filter_params_hash

    service_params = {}
    service_params[:status] = filter_params[:status]
    service_params[:requestor] = filter_params[:requestor]
    service_params[:project] = filter_params[:project]
    service_params[:start_time], service_params[:end_time] = get_sent_params(filter_params[:sent]) if filter_params[:sent]

    return service_params
  end

  def self.is_accessible?(program)
    program.project_based?
  end

  private

  def get_sent_params(sent)
    if sent[:after]
      range_start = Time.now - sent[:after].to_i.days 
    else
      range_start = DEFAULT_START_TIME
    end

    # We don't need to handle the else case as the value will be nil and that ends up as Time.now()
    range_end = Time.now - sent[:before].to_i.days

    return [range_start, range_end]
  end
end
