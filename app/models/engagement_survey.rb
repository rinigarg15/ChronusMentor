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

class EngagementSurvey < Survey
  # http://www.alexreisner.com/code/single-table-inheritance-in-rails
  # Needed to use same controller for all STI classes, required for url_for helper to generate urls properly
  def self.model_name
    Survey.model_name
  end

  def has_associated_tasks_in_active_groups_or_templates?
    active_group_ids = self.program.active_group_ids
    associated_tasks_in_active_groups = MentoringModel::Task.where(group_id: active_group_ids, action_item_id: self.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
    associated_task_templates = MentoringModel::TaskTemplate.where(action_item_id: self.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
    associated_tasks_in_active_groups.present? || associated_task_templates.present?
  end

  def destroyable?
    !self.has_associated_tasks_in_active_groups_or_templates?
  end

  def assigned_overdue_tasks
    completed_closure_reason_ids = program.group_closure_reasons.completed.pluck(:id)
    valid_group_ids = program.groups.where("status IN (?) OR (status = ? AND closure_reason_id IN (?))", Group::Status::ACTIVE_CRITERIA, Group::Status::CLOSED, completed_closure_reason_ids).pluck(:id)
    MentoringModel::Task.where(action_item_id: self.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).where(group_id: valid_group_ids).assigned.overdue
  end
  
  def date_filter_applied(start_date, end_date)
    MentoringModel::Task.for_the_survey_id(self.id).due_date_in(start_date, end_date).pluck(:id)
  end

  def profile_field_filter_applied(user_ids)
    MentoringModel::Task.for_the_survey_id(self.id).owned_by_users_with_ids(user_ids)
  end

  def get_user_for_campaign(task)
    task.user
  end

  def get_object_count(survey_answers)
    survey_answers.pluck('DISTINCT group_id').compact.count  
  end

  def get_answered_ids
    self.survey_answers.pluck(:task_id).uniq.compact  
  end

  def create_scrap_for_progress_report(sender, group, options = {})
    scrap = group.scraps.new
    scrap.program = group.program
    scrap.sender = sender
    scrap.receivers = group.members.active.map(&:member) - [sender]
    scrap.subject = options[:subject]
    scrap.content = options[:content]
    scrap.attachment = options[:attachment]
    scrap.attachment_file_name = "#{self.name}.#{FORMAT::PDF}"
    scrap.transliterate_file_name
    scrap.save!
  end

  def progress_report_file_name
    seed = "#{Time.now.to_i}-#{SecureRandom.hex(6)}"
    "#{self.name.parameterize}-#{seed}"
  end

  def progress_report_s3_location
    "#{PROGRESS_REPORTS_S3_PREFIX}/#{self.id}"
  end

  def self.generate_and_email_progress_report_pdf(survey_id, is_published, options = {})
    user = User.find_by(id: options[:user_id], program_id: options[:program_id])
    survey = EngagementSurvey.find_by(id: survey_id, program_id: options[:program_id])
    group = Group.find_by(id: options[:group_id], program_id: options[:program_id])
    return unless survey.present? && user.present? && group.present?
    locale = options[:locale] || I18n.default_locale
    GlobalizationUtils.run_in_locale(locale) do
      begin
        pdf_file = Tempfile.new([survey.progress_report_file_name, ".#{FORMAT::PDF}"])
        pdf_file.binmode
        scrap_options = progress_report_scrap_options(survey, is_published, pdf_file, options[:s3_file_key])
        survey.create_scrap_for_progress_report(user.member, group, scrap_options)
      ensure
        pdf_file.unlink
      end
    end
  end

  # Inherits other functions from Survey

  private

  def self.progress_report_scrap_options(survey, is_published, pdf_file, s3_file_key)
    scrap_options = {}
    scrap_options[:subject] = get_published_or_updated_survey_name(survey, is_published)
    scrap_options[:content] = "feature.survey.emails.content_html".translate(survey_name: get_published_or_updated_survey_name(survey, is_published, true))
    scrap_options[:attachment] = generate_progress_report_pdf(pdf_file, s3_file_key)
    scrap_options
  end

  def self.generate_progress_report_pdf(pdf_file, s3_file_key)
    s3_object = ChronusS3Utils::S3Helper.get_bucket(APP_CONFIG[:chronus_mentor_common_bucket]).objects[s3_file_key]
    pdf_file.write WickedPdf.new.pdf_from_string(s3_object.read)
    pdf_file.close
    s3_object.delete
    File.open pdf_file.path
  end

  def self.get_published_or_updated_survey_name(survey, is_published, downcase = false)
    translation_key = if is_published
                        "feature.survey.emails.published_survey"
                      else
                        "feature.survey.emails.updated_survey"
                      end
    translation_key += "_downcase" if downcase
    translation_key.translate(survey_name: survey.name)
  end

end
