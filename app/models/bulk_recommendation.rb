# == Schema Information
#
# Table name: bulk_matches
#
#  id                   :integer          not null, primary key
#  mentor_view_id       :integer
#  mentee_view_id       :integer
#  program_id           :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  show_drafted         :boolean          default(FALSE)
#  show_published       :boolean          default(FALSE)
#  sort_value           :string(255)
#  sort_order           :boolean          default(TRUE)
#  request_notes        :boolean          default(TRUE)
#  max_pickable_slots   :integer
#  type                 :string(255)      default("BulkMatch")
#  max_suggestion_count :integer
#  default              :integer          default(0)
#

class BulkRecommendation < AbstractBulkMatch
  DEFAULT_MAX_RECOMMENDATION_COUNT = 1

  MASS_UPDATE_ATTRIBUTES = {
   :update_settings => [:show_drafted, :show_published, :max_pickable_slots, :max_suggestion_count]
  }

end
