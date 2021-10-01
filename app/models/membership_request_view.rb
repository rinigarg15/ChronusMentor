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

class MembershipRequestView < AbstractView
  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    PENDING_MEMBERSHIP_REQUESTS = Proc.new {|program|
      {
        enabled_for: [Program, CareerDev::Portal],
        title: ->{ "feature.abstract_view.mebership_request_view.pending_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.mebership_request_view.pending_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({}) },
        default_view: -> { AbstractView::DefaultType::PENDING_REQUESTS }
      }
    }

    class << self
      def all
        [PENDING_MEMBERSHIP_REQUESTS]
      end
    end
  end

  def count(alert=nil)
    filter_hash = FilterUtils.process_filter_hash_for_alert(self, self.filter_params_hash, alert)
    list_type = filter_hash[:list_type].present? ? filter_hash[:list_type].to_i : MembershipRequest::ListStyle::DETAILED
    MembershipRequestService.get_filtered_membership_requests(self.program, filter_hash, list_type, MembershipRequest::FilterStatus::PENDING, true).count
  end
end
