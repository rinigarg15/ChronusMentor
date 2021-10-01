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

class ProgramInvitationView < AbstractView
  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    PENDING_INVITES =  Proc.new {|program|
      {
        enabled_for: [Program],
        title: ->{ "feature.abstract_view.program_invitation_view.pending_title".translate(program.management_report_related_custom_term_interpolations) },
        description: ->{ "feature.abstract_view.program_invitation_view.pending_description".translate(program.management_report_related_custom_term_interpolations) },
        filter_params: ->{ AbstractView.convert_to_yaml({}) },
        default_view: -> { AbstractView::DefaultType::PENDING_INVITES }
      }
    }

    class << self
      def all
        [PENDING_INVITES]
      end
    end
  end

  def count(alert=nil)
    filter_params = FilterUtils.process_filter_hash_for_alert(self, self.filter_params_hash, alert)
    filter_params[:sent_between_start_time], filter_params[:sent_between_end_time] = CommonFilterService.initialize_date_range_filter_params(filter_params[:sent_between])
    ProgramInvitation.get_filtered_pending_invitations(program, filter_params).count
  end

end
