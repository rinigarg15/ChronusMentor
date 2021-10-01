# == Schema Information
#
# Table name: one_time_flags
#
#  id           :integer          not null, primary key
#  message_tag  :text(65535)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  ref_obj_id   :integer          not null
#  ref_obj_type :string(255)      not null
#

# This model can be used to store if a user has accessed/used/faced a particular warning/message/feature(like tour).
# This model stores the user_id and the tag (particular to the warning/message) to achieve the above.

class OneTimeFlag < ActiveRecord::Base
  module Flags
    module TourTags
      CAMPAIGN_TOUR_TAG = "chronus_campaign_management_campaign_tour"
      CAMPAIGN_DETAILS_TOUR_TAG = "chronus_campaign_management_campaign_details_tour"
      GROUP_SHOW_V2_TOUR_TAG = "group_show_v2_tour"
      CAMPAIGN_PROGRAM_INVITATION_TOUR_TAG = "chronus_campaign_management_invitation_message_tour"
      CAMPAIGN_MESSAGE_TOUR_TAG = "chronus_campaign_management_campaign_message_tour"
      CAMPAIGN_SURVEY_REMINDER_TOUR_TAG = "chronus_campaign_management_survey_reminders_tour"

      def self.all
        [CAMPAIGN_TOUR_TAG, CAMPAIGN_DETAILS_TOUR_TAG, GROUP_SHOW_V2_TOUR_TAG, CAMPAIGN_PROGRAM_INVITATION_TOUR_TAG, CAMPAIGN_MESSAGE_TOUR_TAG, CAMPAIGN_SURVEY_REMINDER_TOUR_TAG]
      end
    end

    module Popups
      MENTEE_GUIDANCE_POPUP_TAG = "mentee_guidance_popup"
      EXPLICIT_PREFERENCE_CREATION_POPUP_TAG = "explicit_preference_creation_popup"
      def self.all
        [MENTEE_GUIDANCE_POPUP_TAG, EXPLICIT_PREFERENCE_CREATION_POPUP_TAG]
      end
    end

    def self.all
      TourTags.all + Popups.all
    end
  end

  belongs_to :ref_obj, polymorphic: true
  validates :ref_obj, presence: true
  validates :message_tag, uniqueness: { scope: [:ref_obj_id, :ref_obj_type] }, inclusion: { in: Flags.all }

  def self.has_tag?(object, tag)
    object.one_time_flags.where(message_tag: tag).exists?
  end
end
