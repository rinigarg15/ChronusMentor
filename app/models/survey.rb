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

require 'csv'
# Represents a survey in the program, created by an administrator.
class Survey < ActiveRecord::Base
  translates :name

  attr_accessor :questions_file, :from_solution_pack

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:name, :type, :due_date, :progress_report],
    :update => [:name, :due_date, :progress_report]
  }

  module EditMode
    NOEDIT = 0
    OVERWRITE = 1
    MULTIRESPONSE = 2
    MULTIEDIT = 3

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module SurveySource
    TASK = 1
    MAIL = 2
    POPUP = 3
    FLASH = 4
    NON_CONN_SURVEY = 5
    MEETING_LISTING = 6
    MEETING_AREA = 7
    HOME_PAGE_WIDGET = 8
    MENTORING_CALENDAR = 9

    GA_NAME = {
      TASK => "task",
      MAIL => "mail",
      POPUP => "popup",
      FLASH => "flash",
      NON_CONN_SURVEY => "non_connection_survey",
      MEETING_LISTING => "meeting_listing",
      MEETING_AREA => "meeting_area",
      HOME_PAGE_WIDGET => "home_page_widget",
      MENTORING_CALENDAR => "mentoring_calendar"
    }
  end

  module Type
    PROGRAM = "ProgramSurvey"
    ENGAGEMENT = "EngagementSurvey"
    MEETING_FEEDBACK = "MeetingFeedbackSurvey"
    def self.all
      [ENGAGEMENT, MEETING_FEEDBACK, PROGRAM]
    end

    def self.admin_createable
      [ENGAGEMENT, PROGRAM]
    end

    def self.engagement_dependent_survey_type
      [ENGAGEMENT]
    end

    def self.program_survey_type
      [PROGRAM]
    end

    def self.for_program
      [PROGRAM, ENGAGEMENT]
    end

    def self.for_portal
      [PROGRAM]
    end

  end

  module FormType
    FEEDBACK = 0
  end

  module Status
    COMPLETED = 1
    OVERDUE = 2
  end

  # Represents the report for a survey, containing detailed information about
  # the responses, number of responses, etc.,
  class Report
    SEPERATOR_QUERY = "---"
    # The survey to which this report belongs to.
    attr_accessor :survey

    # ActiveSupport::OrderedHash from each question to it's QuestionResponse.
    # The order is maintained so that the CSV data content is consistet.
    attr_accessor :question_responses

    def initialize(survey)
      self.survey = survey
      self.question_responses = ActiveSupport::OrderedHash.new
    end

    def add_question(survey_question)
      self.question_responses[survey_question] = survey_question.matrix_question_type? ?  MatrixQuestionResponse.new(survey_question) : QuestionResponse.new(survey_question)
    end

    def get_response(survey_question)
      self.question_responses[survey_question]
    end

    def self.get_updated_report_filter_params(newparams, oldparams, filtertype, format, options={})
      unless format == FORMAT::PDF || format == "xls" || options[:only_new_params]
        return {} unless filtertype.present?
        reject_type = get_reject_match_for_filters(filtertype)
        oldparams.delete_if{|index, filter_hash| filter_hash[:field] =~ reject_type}
      end
      updated_params = {}
      (oldparams.values + newparams.values).each_with_index do |filter_hash, index|
        updated_params[index.to_s] = filter_hash
      end
      return remove_incomplete_report_filters(updated_params)
    end

    def self.remove_incomplete_report_filters(params)
      params.delete_if{|k,v| invalid_filter_hash(v)}
    end

    def self.get_applied_date_range(filter_values, program)
      date_filters = filter_values.select{|v| v["field"] == "date"}
      start_date = date_filters.present? && date_filters.first["value"].present? ? date_filters.first["value"].in_time_zone : program.created_at
      end_date = date_filters.present? && date_filters.size == 2 && date_filters.last["value"].present? ? date_filters.last["value"].in_time_zone : Time.current
      return start_date, end_date
    end

    # If there are no questions or if none of the questions have response, then
    # the report is considered empty.
    def empty?
      non_empty_reponses = self.question_responses.values.reject(&:empty?)
      non_empty_reponses.empty?
    end

    # Response data for a matrix question
    class MatrixQuestionResponse
      attr_accessor :survey_question       # Matrix question to which this data belongs to
      attr_accessor :count                 # Number of responses to the matrix question.
      attr_accessor :data # Detailed data of the responses of the corresponding rating questions.

      def initialize(matrix_survey_question)
        self.survey_question = matrix_survey_question
        self.count = 0
        self.data = []

        # create a QuestionResponse for each of the rating_questions of the matrix surey question
        matrix_survey_question.rating_questions.each do |rq|
          self.data << QuestionResponse.new(rq)
        end
      end

      def add_answers_info(grouped_answers, survey_question_answers_count, survey_matrix_question_answers_count)
        self.count = survey_matrix_question_answers_count[survey_question.id]||0
        self.rating_question_responses.each do |rating_question_response|
          rating_question_response.add_answers_info(grouped_answers, survey_question_answers_count, nil)
        end
      end

      def empty?
        self.count == 0
      end

      def rating_question_responses
        self.data
      end
    end

    # Response data for a question
    class QuestionResponse
      attr_accessor :survey_question # Question to which this data belongs to
      attr_accessor :count           # Number of responses to the question.
      attr_accessor :data            # Detailed data of the responses.

      def initialize(survey_question)
        self.survey_question = survey_question
        self.count = 0
        self.data = survey_question.choice_based? ? {} : []

        # For choice questions, initialize all answer count to 0.
        if survey_question.choice_based?
          survey_question.default_choice_records.each do |question_choice|
            self.data[question_choice.id] = 0
          end
          self.data["other"] = 0 if survey_question.allow_other_option?
        end
      end

      def add_answers_info(grouped_answers, survey_question_answers_count, survey_matrix_question_answers_count)
        answer_text = grouped_answers[survey_question.id].try(:text)
        answers = answer_text.present? ? answer_text.split(Report::SEPERATOR_QUERY) : []
        self.count = answer_text.present? ? grouped_answers[survey_question.id].answers_count : 0
        add_data(answers, survey_question_answers_count) unless answers.blank?
      end

      def add_data(answers, survey_question_answers_count)
        if survey_question.choice_based?
          choices_count = compute_choices_count(answers)

          self.data = choices_count.except("other")
          self.data["other"] = choices_count["other"] if survey_question.allow_other_option?
          self.data.each do |choice, count|
            self.data[choice] = (count / survey_question_answers_count[survey_question.id].to_f) * 100
          end
        else
          self.data = answers
        end
      end

      # count => 0 means there were no responses to this question.
      def empty?
        self.count == 0
      end

      # Converts to a CSV record data string.
      def csv_line
        csv_data = [self.count.to_s]

        # Convert data of the form
        #   {'a' => 'b', 'man' => 'god'}
        # to
        #   a=>b
        #   man=>god
        #
        # and
        #   ["good", "better", "best"]
        #
        # to
        #   good
        #   better
        #   best
        #
        if self.survey_question.choice_based?
          question_choices_hash = survey_question.default_choice_records.index_by(&:id)
          csv_data << self.data.collect{|opt, val| "#{question_choices_hash[opt].try(:text) || opt} => #{val}%"}.join("\n")
        else
          csv_data << self.data.join("\n")
        end
      end

      private

      def compute_choices_count(answers)
        choices_count = {}
        answer_ids = answers.map(&:to_i)

        survey_question.default_choice_records.each do |qc|
          choices_count[qc.id] = qc.answer_choices.select{|ac| answer_ids.include?(ac.ref_obj_id) && ac.ref_obj_type == CommonAnswer.name}.size
        end
        choices_count["other"] = compute_other_choices_count(answer_ids) if survey_question.allow_other_option?
        choices_count
      end

      def compute_other_choices_count(answer_ids)
        other_answer_ids = []
        survey_question.other_choice_records.each do |qc|
          other_answer_ids += qc.answer_choices.select{|ac| answer_ids.include?(ac.ref_obj_id) && ac.ref_obj_type == CommonAnswer.name}.collect(&:ref_obj_id)
        end
        other_answer_ids.uniq.size
      end
    end

    private

    def self.get_reject_match_for_filters(filtertype)
      case filtertype
      when "survey"
        reject_type = /answers/
      when "profile"
        reject_type = /column/
      when "roles"
        reject_type = /roles/
      else
        reject_type = /date/
      end
    end

    def self.invalid_filter_hash(hash)
      (!hash[:field].present?) ||
      ((hash[:field] =~ /column/ || hash[:field] =~ /answers/) && (!hash[:operator].present? || ((hash[:operator] == SurveyResponsesDataService::Operators::CONTAINS || hash[:operator] == SurveyResponsesDataService::Operators::NOT_CONTAINS) && !(hash[:value].present? || hash[:choice].present?))))
    end
  end

  class SurveyResponse
    attr_reader :id, :survey, :question_answer_map, :task_id, :was_draft, :matrix_question_answers_map, :not_published
    #NOTE: Only overwrite and multiresponse modes are implemented
    # options = {user_id => user_id, :group_id => group_id, :task_id => task_id, :response_id => response_id}
    def initialize(survey, options={})
      @survey = survey
      @options = options
      @questions = @survey.survey_questions.includes(:translations, {question_choices: :translations})
      @matrix_rating_questions = @survey.matrix_rating_questions
      @id = @options.delete(:response_id)
      @task_id = @options[:task_id]
      # Only geting survey answers which donot belong to a task if group_id is present and task_id is not present
      @options[:task_id] = nil if (@options[:group_id].present? && !@task_id.present?)
      @is_draft = @options.delete(:is_draft)
      @id ||= SurveyAnswer.unscoped.where(@options).pluck(:response_id).sort.last if @survey.edit_mode == EditMode::OVERWRITE
      @options.merge!(:response_id => @id) if @id.present?
      @was_draft = @id && SurveyAnswer.drafted.where(@options).any?
      old_answer_map = @id.present? ? SurveyAnswer.unscoped.where(@options).includes(:answer_choices).index_by(&:common_question_id) : {}
      @not_published = @was_draft || old_answer_map.blank?
      @question_answer_map = @questions.inject({}) do |qam, question| # Order of inserts is maintained in ruby1.9#Hash
        qam[question] = old_answer_map[question.id] || question.survey_answers.new(@options) #TODO-PERF: NO Need to create empty objects always
        qam
      end
      @matrix_question_answers_map = @matrix_rating_questions.inject({}) do |qam, question|
        qam[question] = old_answer_map[question.id] || question.survey_answers.new(@options)
        qam
      end
    end

    #TODO: Use insert locking of table to prevent inconsistent data on response_id - http://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html
    def save_answers(questionid_newanswer_map)
      ActiveRecord::Base.transaction do
        raise "You cannot edit an existing response" if (@id.present? && @survey.edit_mode == EditMode::MULTIRESPONSE && !@was_draft) # In multiresponse, you can view them, but not edit them
        @id = (SurveyAnswer.unscoped.maximum(:response_id).to_i+1) unless (@id.present? && (@survey.edit_mode == EditMode::OVERWRITE || @was_draft))
        @options.merge!(:response_id => @id)
        @question_answer_map.merge(@matrix_question_answers_map).each do |question, answer|
          next if question.matrix_question_type? || !question.can_be_shown?(@options[:member_meeting_id])
          answer_text = questionid_newanswer_map[question.id]
          answer.answer_value = {answer_text: answer_text, question: question}
          answer.task_id = @options[:task_id]
          answer.group_id = @options[:group_id]
          answer.response_id = @id
          answer.last_answered_at = Time.now.utc
          answer.is_draft = !!@is_draft
          unless answer.save
            @survey.update_total_responses!
            return [false, question, @options]
          end
        end
        @survey.update_total_responses!
        true
      end
    end
  end

  # ASSOCIATIONS ---------------------------------------------------------------
  belongs_to_program

  # questions are sorted by their position.
  has_many :survey_questions, -> {where("matrix_question_id IS NULL").order("position ASC")}, dependent: :destroy
  has_many :survey_questions_with_matrix_rating_questions, -> {order "position ASC"}, :class_name => "SurveyQuestion"
  has_many :survey_answers, :through => :survey_questions_with_matrix_rating_questions
  has_many :survey_answers_without_matrix_answers, :through => :survey_questions, :source => :survey_answers
  has_many :survey_response_columns, -> { order(ref_obj_type: :asc, position: :asc, id: :asc) }, dependent: :destroy
  has_one :campaign, class_name: 'CampaignManagement::SurveyCampaign', foreign_key: :ref_obj_id, dependent: :destroy
  has_many :associated_survey_answers, class_name: "SurveyAnswer"

  # VALIDATIONS ----------------------------------------------------------------
  validates_presence_of :program, :name, :type
  validate :check_feedback_survey # Program can have only one connection feedback survey
  validates :edit_mode, inclusion: {in: EditMode.all}, allow_nil: true
  validates :form_type, inclusion: {in: [FormType::FEEDBACK]}, allow_nil: true
  validate :check_progress_report # Progress report can be set only if SHARE_PROGRESS_REPORTS feature is enabled

  default_scope Proc.new{where("surveys.type != ? OR surveys.role_name IS NOT NULL", MeetingFeedbackSurvey.name)}
  scope :of_program_type, -> { where(:type => ProgramSurvey.name)}
  scope :of_engagement_type, -> { where(:type => EngagementSurvey.name)}
  scope :of_meeting_feedback_type, -> { where(:type => MeetingFeedbackSurvey.name).where.not(role_name: nil)}

  def self.select_options(program)
    if program.ongoing_mentoring_enabled?
      return Type.admin_createable
    else
      return Type.admin_createable - Type.engagement_dependent_survey_type
    end
  end

  def self.by_type(program)
    surveys = program.surveys.includes(:translations)
    surveys_by_type = surveys.present? ? surveys.group_by(&:type) : {}
    Survey::Type.all.each { |survey_type| surveys_by_type[survey_type] ||= [] }

    # Feedback survey is engagement-type survey; classify it as program-survey in
    # V2 disabled programs.
    if program.feedback_survey.present? && program.ongoing_mentoring_enabled? && !program.mentoring_connections_v2_enabled?
      surveys_by_type[ProgramSurvey.name] += [program.feedback_survey]
    end

    # Delete the keys based on feature check. If feature enabled and no surveys of that type present
    # then, return an empty array for that type.
    surveys_by_type.delete(EngagementSurvey.name) unless program.mentoring_connections_v2_enabled? && program.ongoing_mentoring_enabled?
    surveys_by_type.delete(MeetingFeedbackSurvey.name) unless program.calendar_enabled?
    surveys_by_type
  end

  def self.percentage_error(responses_count, total_responses)
    return nil if (responses_count == 0 || total_responses.nil? || total_responses == 1)
    percentage_error = 1.96*0.5*Math.sqrt((total_responses - responses_count).to_f / ((total_responses-1)*responses_count))
    rounded_percentage_error = (percentage_error*100).round(2).ceil
    return rounded_percentage_error
  end

  def tied_to_outcomes_report?
    self.engagement_survey? && self.survey_questions_with_matrix_rating_questions.map(&:positive_outcome_options).compact.any? && self.program.program_outcomes_report_enabled?
  end

  def self.calculate_response_rate(responses_count, total_responses)
    return nil if total_responses.nil? || total_responses == 0
    response_rate = responses_count.to_f / (total_responses)
    rounded_response_rate =  (response_rate*100).round(2)
    return rounded_response_rate
  end

  def program_survey?
    self.type == Type::PROGRAM
  end

  def engagement_survey?
    self.type == Type::ENGAGEMENT
  end

  def meeting_feedback_survey?
    self.type == Type::MEETING_FEEDBACK
  end

  def responses
    # Under normal load we can expect response_id s to be unique
    # This issue will be fixed once we create a separate join table when moving feedback to survey
    survey_answers.group_by(&:response_id)
  end

  def update_total_responses!
    total_responses = self.survey_answers.count("DISTINCT response_id")
    self.update_attribute(:total_responses, total_responses)
  end

  def self.update_total_responses_for_survey!(survey_id)
    survey = Survey.find_by(id: survey_id)
    return unless survey.present?
    survey.update_total_responses!
  end

  # If some errors occurs while saving the answer of a question (say q1),
  # returns [false, q1]. Returns true otherwise
  def update_user_answers(question_id_to_answer_map, options)
    # Sort the hash so that we don't save the answers in some random order.
    # The order in which we save matters since we _return_ on encountering the
    # first error, saving until the previous answer. So, the order should be consistent.
    question_id_to_answer_map.keys.each do |key|
      # Convert string keys to integers
      question_id_to_answer_map[key.to_i] = question_id_to_answer_map.delete(key)
    end
    collect_response = options.delete(:collect_response)
    response = SurveyResponse.new(self, options)
    saved = response.save_answers(question_id_to_answer_map)
    collect_response ? [saved, response] : saved
  end

  # Generates the report data for the survey
  def get_report(options = {})
    survey_questions = options.delete(:survey_questions) || self.survey_questions
    grouped_answers = get_grouped_answers(survey_questions, options)
    question_ids_along_with_matrix_rating_questons = get_question_ids_along_with_matrix_rating_questons(survey_questions)
    survey_question_answers_count = SurveyAnswer.with_response_ids_in(options[:response_ids]).where(common_question_id: question_ids_along_with_matrix_rating_questons).group(:common_question_id).count
    survey_matrix_question_answers_count = SurveyAnswer.select("DISTINCT response_id").with_response_ids_in(options[:response_ids]).where(common_question_id: question_ids_along_with_matrix_rating_questons).joins(:survey_question).group(:matrix_question_id).count

    report = Report.new(self)
    survey_questions.each do |question|
      map_entry = report.add_question(question)
      map_entry.add_answers_info(grouped_answers, survey_question_answers_count, survey_matrix_question_answers_count)
    end
    report
  end

  def get_answers_and_user_names(survey_question_ids, question_id_answer_separator, answer_separator, program_id, options = {})
    is_engagement_survey = options[:is_engagement_survey]
    response_ids = options[:response_ids]

    select_string = "email, CONCAT(first_name, ' ', last_name) AS name, members.id AS member_id, MAX(common_answers.last_answered_at) as timestamp, response_id"
    if survey_question_ids.present?
      select_string += ", GROUP_CONCAT(DISTINCT(CONCAT(common_question_id, '#{question_id_answer_separator}', answer_text)) ORDER BY field(common_question_id, #{survey_question_ids.join(',')}) SEPARATOR '#{answer_separator}') as answers"
      select_string += ", GROUP_CONCAT(DISTINCT(CONCAT(common_question_id, '#{question_id_answer_separator}', answer_choices.question_choice_id)) ORDER BY field(common_question_id, #{survey_question_ids.join(',')}) SEPARATOR '#{answer_separator}') as choices"
    end
    select_string += is_engagement_survey ? ", common_answers.group_id, common_answers.task_id, roles.name AS user_roles" : ", GROUP_CONCAT(DISTINCT(roles.name)) AS user_roles"
    select_string += ", member_meeting_id" if self.meeting_feedback_survey?

    joins_string = is_engagement_survey ? { user: :member } : { user: [:member, :roles] }
    response = SurveyAnswer.select(select_string).with_response_ids_in(response_ids).joins(joins_string).where("users.program_id = ?", program_id).order(:user_id).group(:response_id)
    response = response.joins("LEFT JOIN answer_choices ON answer_choices.ref_obj_id = common_answers.id AND answer_choices.ref_obj_type = #{Survey.connection.quote(CommonAnswer.name)}")
    is_engagement_survey ? response.joins("LEFT JOIN roles ON roles.id = common_answers.connection_membership_role_id") : response
  end

  # Returns whether the given user can attend this survey.
  def allowed_to_attend?(user, task = nil, group = nil, feedback_group = nil, meeting_details={})
    (self.is_feedback_survey? && feedback_group.present? && feedback_group.has_member?(user)) ||
    (self.program_survey? && user.program == self.program && self.has_any_recipient_role?(user.roles)) ||
    (self.engagement_survey? && task.present? && task.connection_membership.user_id == user.id && task.action_item_id == self.id) ||
    (self.engagement_survey? && task.blank? && group.present? && user.belongs_to_group?(group)) ||
    (self.meeting_feedback_survey? && check_meeting_in_past(meeting_details) && user.member.member_meetings.find_by(id: meeting_details[:member_meeting]).present? && check_meeting_role(user.member.member_meetings.find_by(id: meeting_details[:member_meeting]), user))
  end

  def is_feedback_survey?
    self.form_type == FormType::FEEDBACK
  end

  def create_default_survey_response_columns
    default_columns = self.get_default_survey_response_column_keys
    default_columns.each_with_index do |column, position|
      self.survey_response_columns.create!(:column_key => column, :position => position, :ref_obj_type => SurveyResponseColumn::ColumnType::DEFAULT)
    end
  end

  def get_default_survey_response_column_keys
    default_columns = SurveyResponseColumn::Columns.default_columns
    default_columns -= SurveyResponseColumn::Columns.survey_specific unless self.engagement_survey? || self.meeting_feedback_survey?
    default_columns -= [SurveyResponseColumn::Columns::Roles] if self.meeting_feedback_survey?
    default_columns
  end

  def survey_questions_to_display
    survey_question_ids = self.survey_response_columns.of_survey_questions.pluck(:survey_question_id)
    self.survey_questions.where(id: survey_question_ids)
  end

  def profile_questions_to_display
    profile_question_ids = self.survey_response_columns.of_profile_questions.pluck(:profile_question_id)
    profile_questions = self.program.profile_questions_for(program.roles_without_admin_role.pluck(:name), { default: true, skype: false, fetch_all: true })
    profile_questions.select { |question| profile_question_ids.include?(question.id) }
  end

  def save_survey_response_columns(columns_array)
    old_default_columns = self.survey_response_columns.of_default_columns
    old_survey_question_columns = self.survey_response_columns.of_survey_questions
    old_profile_question_columns = self.survey_response_columns.of_profile_questions

    new_default_columns = columns_array[SurveysController::SurveyResponseColumnGroup::DEFAULT] ? columns_array.delete(SurveysController::SurveyResponseColumnGroup::DEFAULT) : []
    new_survey_question_columns = columns_array[SurveysController::SurveyResponseColumnGroup::SURVEY] ? columns_array.delete(SurveysController::SurveyResponseColumnGroup::SURVEY) : []
    new_profile_question_columns = columns_array[SurveysController::SurveyResponseColumnGroup::PROFILE] ? columns_array.delete(SurveysController::SurveyResponseColumnGroup::PROFILE) : []

    ActiveRecord::Base.transaction do
      #update the default columns
      create_update_columns(self, old_default_columns, new_default_columns, SurveyResponseColumn::ColumnType::DEFAULT)
      #update the survey question columns
      create_update_columns(self, old_survey_question_columns, new_survey_question_columns, SurveyResponseColumn::ColumnType::SURVEY)
      #update the profile question columns
      create_update_columns(self, old_profile_question_columns, new_profile_question_columns, SurveyResponseColumn::ColumnType::USER)
    end
  end

  def has_the_default_column?(key)
    self.survey_response_columns.where(column_key: key).present?
  end

  def matrix_rating_questions
    mqs = self.survey_questions.includes(:translations, rating_questions: {matrix_question: {question_choices: :translations}}).select{|q| q.matrix_question_type?}
    mqs.collect(&:rating_questions).flatten
  end

  def get_questions_from_response_columns_for_display
    questions = survey_response_columns.of_survey_questions.includes([survey_question: [:translations, {question_choices: :translations}, rating_questions: [:translations, matrix_question: {question_choices: :translations}]]]).map{|src| src.survey_question.matrix_question_type? ? src.survey_question.rating_questions : src.survey_question}
    return questions.flatten
  end

  def create_survey_questions(questions_content)
    return if questions_content.blank?
    questions_content = CSV.parse(questions_content)
    column_names = questions_content[0]
    id_mappings = {}
    matrix_id_mappings = {}
    self.populate_survey_questions(questions_content, column_names, id_mappings, matrix_id_mappings)
    self.postprocess_import(id_mappings, matrix_id_mappings)
  end

  def populate_survey_questions(questions_content, column_names, id_mappings, matrix_id_mappings)
    rows = questions_content[1..-1]
    old_id = nil
    old_matrix_id = nil
    rows.each do |row|
      obj = SurveyQuestion.new
      matrix_question_index = column_names.index("matrix_question_id")
      column_names.each_with_index do |column, index|
        if column == "id"
          old_id = row[index].to_i
        else
          populate_survey_question_columns(obj, column, row[index], row[matrix_question_index])
        end
      end
      obj.program_id = self.program_id
      obj.survey_id = self.id
      old_matrix_id = obj.matrix_question_id
      obj.matrix_question_id = nil
      obj.skip_column_creation = old_matrix_id.present?
      obj.save(validate: false)
      id_mappings[old_id] = obj.id
      matrix_id_mappings[old_id] = old_matrix_id
    end
  end

  def postprocess_import(id_mappings, matrix_id_mappings)
    populate_matrix_question_id(id_mappings, matrix_id_mappings)
    validate_survey_questions
  end

  def populate_matrix_question_id(id_mappings, matrix_id_mappings)
    inverted_id_mappings = id_mappings.invert
    self.survey_questions_with_matrix_rating_questions.each do |survey_question|
      survey_question.matrix_question_id = id_mappings[matrix_id_mappings[inverted_id_mappings[survey_question.id]]]
      survey_question.save(validate: false)
    end
  end

  def validate_survey_questions
    Survey.find(self.id).survey_questions_with_matrix_rating_questions.each do |survey_question|
      survey_question.save!
    end
  end

  def show_response_rates?
    self.engagement_survey? || self.meeting_feedback_survey?
  end

  def find_users_who_responded(response_ids)
    survey_answers = self.survey_answers.where(response_id: response_ids)
    users_count = survey_answers.pluck('DISTINCT user_id').count
    object_count = get_object_count(survey_answers)
    return users_count, object_count
  end

  def calculate_overdue_responses(user_ids, filter_params)
    return nil, nil if filter_params[:survey_question_fields].present?

    answered_ids =  get_answered_ids

    filtered_object_ids = date_filter(filter_params) 
    
    filtered_object_ids = filtered_object_ids & profile_field_filter_applied(user_ids) if filter_params[:profile_field_filters].present?

    filtered_object_ids = filtered_object_ids & engagement_role_filter(filter_params) if filter_params[:user_roles].present? && self.engagement_survey?

    total_overdue_ids =  filtered_object_ids - answered_ids
    
    return  total_overdue_ids.count, total_overdue_ids 
  end

  def date_filter(filter_params)
    filtered_object_ids = []
    if(filter_params[:date].present? && (filter_params[:date].include?("null") || filter_params[:date].include?(""))) || filter_params[:date].blank?
      start_date = (self.engagement_survey? ? self.program.created_at : nil)
      filtered_objects_or_ids = date_filter_applied(start_date, Time.now.utc.to_date.at_beginning_of_day)
    else
      filtered_objects_or_ids = date_filter_applied(filter_params[:date][0].to_time, filter_params[:date][1].to_time) 
    end
    return self.engagement_survey? ? filtered_objects_or_ids : find_total_member_meeting_ids(filtered_objects_or_ids)
  end

  def find_total_member_meeting_ids(filtered_member_meetings)
    if self.role_name == RoleConstants::MENTOR_NAME
      return filtered_member_meetings.for_mentor_role.pluck(:id).uniq
    elsif self.role_name == RoleConstants::STUDENT_NAME
      return filtered_member_meetings.for_mentee_role.pluck(:id).uniq
    end
  end

  def engagement_role_filter(filter_params)
    role_ids = self.program.roles.for_mentoring.where(name: SurveyResponsesDataService::FilterResponses.get_roles_from_filters(filter_params)).pluck(:id)
    task_ids_after_role_filter = MentoringModel::Task.for_the_survey_id(self.id).joins(:connection_membership).where("connection_memberships.role_id IN (?)",role_ids).pluck(:id).uniq 
    return task_ids_after_role_filter
  end

  def find_users_groups_with_overdue_responses(task_ids)
    connection_membership_ids = MentoringModel::Task.for_the_survey_id(self.id).where(id: task_ids).pluck(:connection_membership_id)
    users_count = Connection::Membership.where(id:connection_membership_ids).pluck(:user_id).uniq.count
    groups_count = MentoringModel::Task.for_the_survey_id(self.id).where(id: task_ids).pluck(:group_id).uniq.count
    return users_count, groups_count
  end

  def get_questions_for_report_filters
    survey_questions_with_matrix_rating_questions.not_matrix_questions.includes([:translations, matrix_question: [:translations]])
  end

  def get_questions_in_order_for_report_filters(survey_questions_loaded = nil)
    survey_questions_loaded ||= survey_questions.includes([:translations, {question_choices: :translations}, rating_questions: [:translations, matrix_question: {question_choices: :translations}]])
    survey_questions_loaded.map{|sq| sq.matrix_question_type? ? sq.rating_questions : sq}.flatten
  end

  def tied_to_health_report?
    self.is_feedback_survey? && self.survey_questions.non_editable.present?
  end

  def destroyable?
    raise "Method should be defined in child class."
  end

  def create_default_campaign(create_messages=true)
    return if (campaign.present? || !can_have_campaigns?)
    campaign = self.build_campaign(program_id: self.program_id, title: "feature.survey.content.Reminders".translate)
    build_default_campaign_messages(campaign) if create_messages
    campaign.save!
  end

  def build_default_campaign_messages(campaign)
    default_data = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_#{self.type.underscore}_reminders.yml")).result)
    default_data["reminders"].each do |reminder|
      campaign.build_message(reminder["subject"], reminder["source"], reminder["duration"])
    end
  end

  def can_have_campaigns?
    engagement_survey? || meeting_feedback_survey?
  end

  def reminders_count
    can_have_campaigns? ? campaign.campaign_messages.count : nil
  end

  def last_question_for_meeting_cancelled_or_completed_scenario?(question, new_condition)
    return false unless meeting_feedback_survey?
    if question.for_completed? && has_only_one_completed_question? && !SurveyQuestion::Condition.completed_conditions.include?(new_condition)
      return SurveyQuestion::Condition::COMPLETED
    elsif question.for_cancelled? && has_only_one_cancelled_question? && !SurveyQuestion::Condition.cancelled_conditions.include?(new_condition)
      return SurveyQuestion::Condition::CANCELLED
    else
      return false
    end
  end

  def get_survey_questions_for_outcomes(for_management_report=false)
    self.get_questions_in_order_for_report_filters.select(&:choice_based?).map{|question| {id: question.id,
        text: question.question_text_for_display,
        choices: question.values_and_choices.map{|eng_value, locale_value| {id: eng_value, text: locale_value}},
        selected: question.positive_choices(for_management_report)}}
  end

  def can_share_progress_report?(group)
    self.engagement_survey? && self.progress_report? && self.program.share_progress_reports_enabled? && group.scraps_enabled? && group.active?
  end

  private

  def populate_survey_question_columns(obj, column, value, matrix_question_id)
    case column
    when "question_info"
      return if value.blank? || matrix_question_id.present?
      choices = value.split_by_comma
      choices.each_with_index do |text, position|
        obj.question_choices.build(text: text, is_other: false, position: position + 1)
      end
    else
      obj.send("#{column}=", value)
    end
  end

  def check_meeting_role(member_meeting, user)
    self.role_name == member_meeting.meeting.get_role_of_user(user)
  end

  def check_meeting_in_past(meeting_details)
    meeting = meeting_details[:member_meeting].meeting
    meeting.calendar_time_available? ? meeting.archived?(meeting_details[:meeting_timing]) : (!meeting.meeting_request.present? || meeting.meeting_request.accepted?)
  end

  def get_grouped_answers(survey_questions, options = {})
    all_choice_based_questions,  non_choice_based_question = survey_questions.partition{|ques| ques.choice_based?}
    matrix_questions, choice_based_question = all_choice_based_questions.partition{|ques| ques.matrix_question_type?}
    matrix_rating_question_ids = SurveyQuestion.where(matrix_question_id: matrix_questions.collect(&:id)).pluck(:id)

    select_string = "common_question_id, GROUP_CONCAT(common_answers.id SEPARATOR '#{Report::SEPERATOR_QUERY}') as text, COUNT(common_answers.id) as answers_count"
    select_string_with_limit = "common_question_id,  SUBSTRING_INDEX(GROUP_CONCAT(answer_text SEPARATOR '#{Report::SEPERATOR_QUERY}'), '#{Report::SEPERATOR_QUERY}', #{SurveyQuestion::ANSWERS_LIMIT_IN_REPORT}) as text, COUNT(id) as answers_count"
    lookup_string = "feature.survey.survey_report.next_sheet_lookup".translate
    export_string = "common_question_id, COUNT(id) as answers_count, '#{lookup_string}' AS text"

    answers = get_question_answer_text(select_string, choice_based_question.collect(&:id), options[:response_ids])
    select_string_for_non_choice = options[:export] ? export_string : select_string_with_limit
    answers.merge!(get_question_answer_text(select_string_for_non_choice, non_choice_based_question.collect(&:id), options[:response_ids]))
    answers.merge(get_question_answer_text(select_string, matrix_rating_question_ids, options[:response_ids]))
  end

  def get_question_answer_text(select_string, question_ids, response_ids=nil)
    SurveyAnswer.select(select_string).where(common_question_id: question_ids).with_response_ids_in(response_ids).group(:common_question_id).index_by(&:common_question_id)
  end

  def check_feedback_survey
    if self.program.present?
      return true if (self.form_type != FormType::FEEDBACK || !self.program.feedback_survey.present? || self.program.feedback_survey.id == self.id)
      self.errors.add(:form_type, "activerecord.custom_errors.survey.more_than_one_feedback_survey".translate(program: self.program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase))
    end
  end

  def check_progress_report
    return true if self.engagement_survey? && self.program.share_progress_reports_enabled?
    if self.progress_report?
      self.errors.add(:progress_report, "activerecord.custom_errors.survey.cannot_set_progress_report".translate(mentoring_connection: self.program.organization.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase))
    end
  end

  def create_update_columns(survey, old_columns, new_columns, ref_obj_type)
    new_columns.each_with_index do |column_key, index|
      column_object = SurveyResponseColumn.find_object(old_columns, column_key, ref_obj_type)
      if column_object.present?
        column_object.update_attributes!(:position => index)
        old_columns -= [column_object]
      else
        attrs = {:survey => survey, :position => index, :ref_obj_type => ref_obj_type}
        case ref_obj_type
        when SurveyResponseColumn::ColumnType::DEFAULT
          attrs.merge!({:column_key => column_key})
        when SurveyResponseColumn::ColumnType::SURVEY
          attrs.merge!({:survey_question_id => column_key.to_i})
        when SurveyResponseColumn::ColumnType::USER
          attrs.merge!({:profile_question_id => column_key.to_i})
        end
        column_object = SurveyResponseColumn.create!(attrs)
      end
    end
    old_columns.each{|column| column.destroy}
  end

  def get_question_ids_along_with_matrix_rating_questons(survey_questions)
    matrix_question_ids = survey_questions.select{|sq| sq.matrix_question_type?}.collect(&:id)
    matrix_rating_question_ids = SurveyQuestion.where(matrix_question_id: matrix_question_ids).pluck(:id)
    survey_questions.select{|sq| !sq.matrix_question_type?}.collect(&:id) + matrix_rating_question_ids
  end
end
