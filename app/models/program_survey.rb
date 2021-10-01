# == Schema Information
#
# Table name: surveys
#
#  id              :integer          not null, primary key
#  program_id      :integer
#  name            :string(255)
#  due_date        :date
#  created_at      :datetime
#  updated_at      :datetime
#  total_responses :integer          default(0), not null
#  type            :string(255)
#  edit_mode       :integer
#  form_type       :integer
#  role_name       :string(255)
#

class  ProgramSurvey < Survey
  # http://www.alexreisner.com/code/single-table-inheritance-in-rails
  # Needed to use same controller for all STI classes, required for url_for helper to generate urls properly
  def self.model_name
    Survey.model_name
  end

  acts_as_role_based(:role_association => 'recipient_role')

  validate :check_due_date_is_valid

  scope :not_expired, -> {where("due_date IS NULL OR due_date >= ?", Time.now.to_date)}
  scope :expired, -> {where("due_date < ?", Time.now.to_date)}

  # INSTANCE METHODS -----------------------------------------------------------

  def formatted_due_date
    DateTime.localize(self.due_date, format: :short) if self.due_date
  end

  def formatted_due_date=(time_str)
    new_date = Date.strptime(time_str, '%B %d, %Y')
    self.due_date = new_date
  rescue ArgumentError
    # Catch any exception that might arise due to empty string or some other
    # text passed as time_str, that is not a date string.
    logger.info "activerecord.errors.models.survey.attributes.due_date.date_parsing".translate(time_str: time_str)
  end

  def overdue?
    self.due_date && self.due_date < Time.now.to_date
  end

  def destroyable?
    true
  end

  private
  # Make sure due_date occurs in past, if present.
  def check_due_date_is_valid
    if self.overdue?
      self.errors.add(:due_date, "activerecord.errors.models.survey.attributes.due_date.old_date".translate)
    end
  end

end
