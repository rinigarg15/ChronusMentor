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

class MeetingRequestView < AbstractView
  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    PENDING_MEETING_REQUESTS = Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.meeting_request_view.pending_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.meeting_request_view.pending_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({list: :active}) },
        default_view: -> { AbstractView::DefaultType::PENDING_MEETING_REQUESTS }
      }
    }

    class << self
      def all
        [PENDING_MEETING_REQUESTS]
      end
    end
  end

  def self.is_accessible?(program)
    program.career_based? && program.calendar_enabled?
  end

  def count(alert=nil)
    filter_hash = FilterUtils.process_filter_hash_for_alert(self, self.filter_params_hash, alert)    
    MeetingRequest.get_meeting_requests(program, params: filter_hash)[:meeting_requests].count
  end
end
