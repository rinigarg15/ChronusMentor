# == Schema Information
#
# Table name: group_closure_reasons
#
#  id           :integer          not null, primary key
#  reason       :string(255)
#  is_deleted   :boolean          default(FALSE)
#  is_completed :boolean          default(FALSE)
#  is_default   :boolean          default(FALSE)
#  program_id   :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class GroupClosureReason < ActiveRecord::Base

  translates :reason, fallbacks_for_empty_translations: true

  belongs_to_program

  has_many :groups, foreign_key: "closure_reason_id"
  has_many :auto_terminated_programs, foreign_key: 'auto_terminate_reason_id', class_name: "Program"

  scope :completed, -> { where(is_completed: true) }
  scope :incomplete, -> { where(is_completed: [false, nil]) }
  scope :default, -> { where(is_default: true) }
  scope :non_default, -> { where(is_default: false) }
  scope :permitted, -> { where(is_deleted: false) }

  module DefaultClosureReason
    module Key
      ACCOMPLISHED_GOALS_OF_MENTORSHIP = "accomplished_goals_of_mentorship"
      LACK_OF_COMMUNICATION = "lack_of_communication"
      NEEDS_CHANGED = "needs_changed"
      OTHER = "other"
      AUTO_TERMINATED = "auto_terminated"
      CONNECTION_ENDED = "connection_ended"
    end

    def self.translate(key, options = {})
      "feature.group_closure_reasons.default.#{key.to_s}".translate(options)
    end

    def self.all(options = {})
      {
        Key::ACCOMPLISHED_GOALS_OF_MENTORSHIP => {:reason => translate(Key::ACCOMPLISHED_GOALS_OF_MENTORSHIP, :mentoring_connection => options[:mentoring_connection]), :is_completed => true},
        Key::LACK_OF_COMMUNICATION => {:reason => translate(Key::LACK_OF_COMMUNICATION)},
        Key::NEEDS_CHANGED => {:reason => translate(Key::NEEDS_CHANGED, :mentoring_connection => options[:mentoring_connection])},
        Key::OTHER => {:reason => translate(Key::OTHER)},
        Key::AUTO_TERMINATED => {:reason => translate(Key::AUTO_TERMINATED), :is_default => true},
        Key::CONNECTION_ENDED => {:reason => translate(Key::CONNECTION_ENDED, :Mentoring_Connection => options[:Mentoring_Connection]), :is_default => true, :is_completed => true}
      }
    end
  end

end
