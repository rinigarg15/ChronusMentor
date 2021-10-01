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

class MeetingFeedbackSurvey < Survey
  # http://www.alexreisner.com/code/single-table-inheritance-in-rails
  # Needed to use same controller for all STI classes, required for url_for helper to generate urls properly
  validates :role_name, presence: true

  def self.model_name
    Survey.model_name
  end

  def destroyable?
    false
  end
  # Inherits other functions from Survey

  def add_default_questions!(custom_terms_hash)
    default_data = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_meeting_feedback_survey_for_#{role_name}.yml")).result)
    default_data["questions"].each do |question_data|
      choices = question_data.delete("question_choices") || []
      survey_question = self.survey_questions.new(process_yml_data(question_data, custom_terms_hash))
      choices.each_with_index do |choice, index|
        choice = (choice % custom_terms_hash) if choice.is_a?(String)
        survey_question.question_choices.build(text: choice, position: index + 1, ref_obj: survey_question)
      end if choices.present?
      survey_question.create_survey_question
    end
  end

  def get_user_for_campaign(member_meeting)
    member_meeting.user
  end

  def member_meetings_past_end_time
    program.meetings.non_group_meetings.past.accepted_meetings.includes(:member_meetings).map{|m| select_correct_member_meeting(m)}.reject{|mm| mm.nil?}
  end

  def date_filter_applied(start_date, end_date)
    meeting_ids = start_date.present? ? self.program.meetings.non_group_meetings.accepted_meetings.with_endtime_in(start_date,end_date).pluck(:id) : self.program.meetings.non_group_meetings.accepted_meetings.with_endtime_less_than(end_date).pluck(:id)
    return self.program.member_meetings.where(:meeting_id => meeting_ids)
  end

  def profile_field_filter_applied(user_ids)
    self.program.member_meetings.where(:member_id => find_member_ids(user_ids), :meeting_id => self.program.meetings.accepted_meetings).pluck(:id)
  end

  def find_member_ids(user_ids)
    self.program.users.where(:id => user_ids).pluck(:member_id)
  end

  def get_object_count(survey_answers)
    member_meeting_ids = survey_answers.pluck('DISTINCT member_meeting_id')
    return MemberMeeting.where(:id => member_meeting_ids).pluck(:meeting_id).uniq.count
  end

  def get_answered_ids
    self.survey_answers.pluck(:member_meeting_id).uniq.compact
  end

  def get_answered_meeting_ids
    MemberMeeting.where(id: get_answered_ids).pluck(:meeting_id).uniq
  end

  private

  def has_only_one_completed_question?
    survey_questions.select{|question| question.for_completed?}.size == 1
  end

  def has_only_one_cancelled_question?
    survey_questions.select{|question| question.for_cancelled?}.size == 1
  end

  def select_correct_member_meeting(meeting)
    member_meeting = meeting.get_member_meeting_for_role(role_name)
    member_meeting && !member_meeting.feedback_request_sent? ? member_meeting : nil
  end

  def process_yml_data(question_data, custom_terms_hash)
    processed_data = {}
    question_data.each do |key, val|
      processed_data[key.to_sym] = val.is_a?(String) ? (val % custom_terms_hash) : val
    end
    processed_data[:program_id] = self.program_id
    return processed_data
  end
end
