class MentoringModel::Importer
  ROLE_MAPPING = {
    'mentor' => RoleConstants::MENTOR_NAME,
    'mentee' => RoleConstants::STUDENT_NAME
  }
  ROLE_DELIMITER = ", "

  attr_accessor :milestone_template_rows, :goal_template_rows, :task_template_rows, :facilitation_message_rows
  include ImportExportUtils

  module MentoringTemplate
    BLOCK_IDENTIFIER = '#MentoringTemplate'
    FIELD_HEADER_ORDER = [:goal_progress_type, :allow_due_date_edit, :allow_messaging, :allow_forum, :forum_help_text]
    STATUS_DATA_INTERPRETOR = (->(x,options){ x.strip.downcase.eql?(MentoringModel::Exporter::MentoringTemplate::Status::ENABLED.downcase) })
    DATA_INTERPRETOR = {
      goal_progress_type: (->(x,options){ x.strip.downcase.eql?(MentoringModel::Exporter::MentoringTemplate::GoalType::MANUAL.downcase) ? MentoringModel::GoalProgressType::MANUAL : MentoringModel::GoalProgressType::AUTO}),
      allow_due_date_edit: STATUS_DATA_INTERPRETOR,
      allow_messaging: STATUS_DATA_INTERPRETOR,
      allow_forum: STATUS_DATA_INTERPRETOR
    }
  end

  module MilestoneTemplate
    BLOCK_IDENTIFIER = '#Milestones'
    FIELD_HEADER_ORDER = [:title, :description, :position]
    DATA_INTERPRETOR = {}
  end

  module GoalTemplate
    BLOCK_IDENTIFIER = '#Goals'
    FIELD_HEADER_ORDER = [:title, :description]
    DATA_INTERPRETOR = {}
  end

  module TaskTemplate
    module ActionItemIdentifier
      MEETING = 'Create Meeting'
      GOAL = 'Setup Goal'
      ENGAGEMENT_SURVEY = 'Take Engagement Survey'
    end
    START_OF_CONNECTION_IDENTIFIER = 'Start'
    BLOCK_IDENTIFIER = '#Tasks'
    FIELD_HEADER_ORDER = [:title, :description, :required, :duration, :associated_id, :action_item_type, :action_item_id, :role_id, :goal_template_id, :milestone_template_id, :specific_date]
    DATA_INTERPRETOR = {
      required: (->(x,options){ x.strip.downcase.eql?("Yes".downcase) ? true : false }),
      duration: (->(x,options){ x.present? ? x.strip.to_i : 0 }),
      associated_id: (->(x,options) {(x && x.strip.eql?(START_OF_CONNECTION_IDENTIFIER) ? nil : ((x && options[:tasks_referenced_by_title][x.strip].try(:id)) || options[:tasks_referenced_by_title].values.select(&:present?).select(&:required?).last.try(:id)))}),
      action_item_type: (->(x,options){ (x && {ActionItemIdentifier::MEETING.downcase => MentoringModel::TaskTemplate::ActionItem::MEETING, ActionItemIdentifier::GOAL.downcase => MentoringModel::TaskTemplate::ActionItem::GOAL, ActionItemIdentifier::ENGAGEMENT_SURVEY.downcase => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY}[x.strip.downcase]) || MentoringModel::TaskTemplate::ActionItem::DEFAULT }),
      action_item_id: (->(x,options) { x.present? ? x.strip.to_i : nil}),
      role_id: (->(x,options){ x && options[options[:custom_role_map][x.strip.downcase]|| ROLE_MAPPING[x.strip.downcase] || x.strip.downcase].try(:id) }),
      goal_template_id: (->(x,options){ x && options[:goals_referenced_by_title][x.strip].try(:id) }),
      milestone_template_id: (->(x,options){ x && options[:milestones_referenced_by_title][x.strip].try(:id) }),
      specific_date: (->(x,options){ x.present? ? DateTime.strptime(x.strip, "%m/%d/%Y").strftime("%Y/%m/%d").to_date : nil })
    }
  end

  module FacilitationMessageTemplate
    BLOCK_IDENTIFIER = '#Facilitation Messages'
    FIELD_HEADER_ORDER = [:subject, :message, :role_names, :send_on, :milestone_template_id, :specific_date]
    DATA_INTERPRETOR = {
      role_names: (->(x,options){ x.present? ? x.downcase.split(ROLE_DELIMITER).map{|r| options[:custom_role_map][r.strip] || ROLE_MAPPING[r.strip] || r.strip} : [RoleConstants::STUDENT_NAME] }),
      send_on: (->(x,options){ x.present? ? x.strip.to_i : nil}),
      milestone_template_id: (->(x,options){ x && options[:milestones_referenced_by_title][x.strip].try(:id) }),
      specific_date: (->(x,options){ x.present? ? DateTime.strptime(x.strip, "%m/%d/%Y").strftime("%Y/%m/%d").to_date : nil })
    }
  end

  ITEM_TO_DATA_MODULE_MAPPER = {
    mentoring_model_template: MentoringTemplate,
    milestone_template: MilestoneTemplate,
    goal_template: GoalTemplate,
    task_template: TaskTemplate,
    facilitation_message: FacilitationMessageTemplate
  }
  DEFAULT_DATA_INTERPRETOR = (->(x,options){x.respond_to?(:strip) ? x.strip : x})

  def initialize(mentoring_model, csv_content)
    @csv_content = csv_content
    exception_processing_block("feature.mentoring_model.description.error_in_csv_file_format", re_raise: false) do
      @data = CSV.parse(@csv_content)
    end
    @mentoring_model = mentoring_model
    @program = @mentoring_model.program
    @successful = false
    @milestones_referenced_by_title = {}
    @goals_referenced_by_title = {}
    @tasks_referenced_by_title = {TaskTemplate::START_OF_CONNECTION_IDENTIFIER => nil}
    @custom_role_map = RoleConstants.program_roles_mapping(@program).each{|k,v| v.downcase!}.invert
    @role_mapping = {}
    @user_roles = []
    @admin_roles = []
    @all_roles = []
    @program.roles.for_mentoring_models.each do |role|
      @role_mapping[role.name.downcase] = role
      @all_roles << role
      @user_roles << role if role.for_mentoring?
      @admin_roles << role if role.administrative?
    end
  end

  def import(skip_survey_validations = false)
    unless @error_message_key
      begin
        ActiveRecord::Base.transaction do
          exception_processing_block("feature.mentoring_model.description.error_in_removing_content") do
            cleanup_existing_mentoring_model_items(@mentoring_model)
          end
          exception_processing_block("feature.mentoring_model.description.error_in_extracting_content") do
            item_headers = [:mentoring_model_template, :milestone_template, :goal_template, :task_template, :facilitation_message]
            extract_data_rows_from_csv_data(self, @data, ITEM_TO_DATA_MODULE_MAPPER, item_headers)
          end
          exception_processing_block("feature.mentoring_model.description.error_in_roles") do
            raise unless validate_task_template_and_facilitation_message_roles
          end
          exception_processing_block("feature.mentoring_model.description.error_in_mentoring_model_content") do
            update_mentoring_model_on_extracted_data!(@mentoring_model, @mentoring_model_template_rows, @goal_template_rows, @task_template_rows)
          end
          exception_processing_block("feature.mentoring_model.description.error_updating_permissions") do
            update_permission_based_on_extracted_data!(@mentoring_model, @milestone_template_rows, @goal_template_rows, @task_template_rows)
          end
          exception_processing_block("feature.mentoring_model.description.error_in_milestones_content") do
            raise unless validate_task_template_references(@task_template_rows, @milestone_template_rows, MilestoneTemplate, :milestone_template_id)
            populate_milestone_templates_and_update_title_references(@mentoring_model, @milestone_template_rows, @milestones_referenced_by_title)
          end
          exception_processing_block("feature.mentoring_model.description.error_in_goals_content") do
            raise unless validate_task_template_references(@task_template_rows, @goal_template_rows, GoalTemplate, :goal_template_id)
            populate_goal_templates_and_update_title_references(@mentoring_model, @goal_template_rows, @goals_referenced_by_title)
          end
          exception_processing_block("feature.mentoring_model.description.error_in_facilitation_messages_content_v2") do
            populate_facilitation_templates(@mentoring_model, @facilitation_message_rows, @milestones_referenced_by_title, skip_survey_validations)
          end
          exception_processing_block("feature.mentoring_model.description.error_in_tasks_content_v2") do
            populate_task_templates(@mentoring_model, @task_template_rows, @milestones_referenced_by_title, @goals_referenced_by_title, @tasks_referenced_by_title, skip_survey_validations)
            @mentoring_model.mentoring_model_task_templates.each_with_index do |task_template, index|
              task_template.position = index
              task_template.skip_survey_validations = skip_survey_validations
              task_template.skip_due_date_computation = true
              task_template.save!
            end
          end
          @successful = true
        end
      rescue => exception
        @successful = false
        Airbrake.notify(exception)
      end
    end
    self
  end

  def successful?
    @successful
  end

  def error_message_key
    @error_message_key || "feature.mentoring_model.description.processing_import"
  end

  def process_ckeditor_content(content)
    content.gsub("\n", "<br/>") if content.present?
  end

  private

  def exception_processing_block(error_key, options = {})
    options.reverse_merge!({re_raise: true})
    begin
      yield
    rescue => exception
      @error_message_key = error_key
      raise exception if options[:re_raise]
    end
  end

  def cleanup_existing_mentoring_model_items(mentoring_model)
    mentoring_model.mentoring_model_task_templates.destroy_all
    mentoring_model.mentoring_model_facilitation_templates.destroy_all
    mentoring_model.mentoring_model_goal_templates.destroy_all
    mentoring_model.mentoring_model_milestone_templates.destroy_all
  end

  def update_mentoring_model_on_extracted_data!(mentoring_model, mentoring_model_template_rows, goal_template_rows, task_template_rows)
    action_item_type_index = TaskTemplate::FIELD_HEADER_ORDER.index(:action_item_type)
    setup_goal_rows = task_template_rows.select{|t| t[action_item_type_index] && t[action_item_type_index].downcase.eql?(TaskTemplate::ActionItemIdentifier::GOAL.downcase)}
    update_goal_type = mentoring_model_template_rows.present? && (goal_template_rows.present? || setup_goal_rows.present?)
    populate_item_with_row_data!(:mentoring_model_template, mentoring_model, mentoring_model_template_rows.first) if mentoring_model_template_rows.present?
    mentoring_model.goal_progress_type = MentoringModel::GoalProgressType::AUTO unless update_goal_type
    mentoring_model.save!
  end

  def update_permission_based_on_extracted_data!(mentoring_model, milestone_template_rows, goal_template_rows, task_template_rows)
    action_item_type_index = TaskTemplate::FIELD_HEADER_ORDER.index(:action_item_type)
    setup_goal_rows = task_template_rows.select{|t| t[action_item_type_index] && t[action_item_type_index].downcase.eql?(TaskTemplate::ActionItemIdentifier::GOAL.downcase)}
    mentoring_model.send("#{milestone_template_rows.present? ? 'allow' : 'deny'}_#{ObjectPermission::MentoringModel::MILESTONE}!", @all_roles)
    mentoring_model.send("#{goal_template_rows.present? || setup_goal_rows.present? ? 'allow' : 'deny'}_#{ObjectPermission::MentoringModel::GOAL}!", @all_roles)
    mentoring_model.send("allow_#{ObjectPermission::MentoringModel::TASK}!", @all_roles)
    mentoring_model.send("allow_#{ObjectPermission::MentoringModel::FACILITATION_MESSAGE}!", @admin_roles)
    mentoring_model.send("allow_#{ObjectPermission::MentoringModel::MEETING}!", @user_roles)
    mentoring_model.send("allow_#{ObjectPermission::MentoringModel::ENGAGEMENT_SURVEY}!", @admin_roles)
  end

  def populate_milestone_templates_and_update_title_references(mentoring_model, milestone_template_rows, milestones_referenced_by_title)
    milestone_template_rows.each_with_index.map do |milestone_template_row_data, index|
      milestone_template = mentoring_model.mentoring_model_milestone_templates.new
      populate_item_with_row_data!(:milestone_template, milestone_template, milestone_template_row_data)
      milestone_template.save!
      milestone_template
    end.each do |milestone_template|
      milestones_referenced_by_title[milestone_template.title] = milestone_template
    end
  end

  def populate_goal_templates_and_update_title_references(mentoring_model, goal_template_rows, goals_referenced_by_title)
    goal_template_rows.each_with_index.map do |goal_template_row_data, index|
      goal_template = mentoring_model.mentoring_model_goal_templates.new
      populate_item_with_row_data!(:goal_template, goal_template, goal_template_row_data)
      goal_template.save!
      goal_template
    end.each do |goal_template|
      goals_referenced_by_title[goal_template.title] = goal_template
    end
  end

  def populate_facilitation_templates(mentoring_model, facilitation_template_rows, milestones_referenced_by_title, skip_survey_validations=false)
    facilitation_template_rows.each_with_index do |facilitation_template_row_data, index|
      facilitation_template = mentoring_model.mentoring_model_facilitation_templates.new
      populate_item_with_row_data!(:facilitation_message, facilitation_template, facilitation_template_row_data)
      facilitation_template.message = process_ckeditor_content(facilitation_template.message)
      facilitation_template.skip_survey_validations = skip_survey_validations
      facilitation_template.save!
    end
  end

  def populate_task_templates(mentoring_model, task_template_rows, milestones_referenced_by_title, goals_referenced_by_title, tasks_referenced_by_title, skip_survey_validations=false)
    task_template_rows.each_with_index do |task_template_row_data, index|
      task_template = mentoring_model.mentoring_model_task_templates.new
      populate_item_with_row_data!(:task_template, task_template, task_template_row_data)
      task_template.skip_due_date_computation = true
      task_template.skip_associated_id_filling = true
      task_template.skip_survey_validations = skip_survey_validations
      task_template.goal_template_id = nil unless task_template.required?
      task_template.description = process_ckeditor_content(task_template.description)
      task_template.save!
      tasks_referenced_by_title[task_template.title] = task_template
    end
  end

  def populate_item_with_row_data!(item_key, item, row_data, milestones_referenced_by_title = @milestones_referenced_by_title, goals_referenced_by_title = @goals_referenced_by_title, tasks_referenced_by_title = @tasks_referenced_by_title, custom_role_map = @custom_role_map)
    item_constants_module = ITEM_TO_DATA_MODULE_MAPPER[item_key]
    options = {
      milestones_referenced_by_title: milestones_referenced_by_title,
      goals_referenced_by_title: goals_referenced_by_title,
      tasks_referenced_by_title: tasks_referenced_by_title,
      custom_role_map: custom_role_map
    }
    options.merge!(@role_mapping)
    item_constants_module::FIELD_HEADER_ORDER.each_with_index do |attribute, index|
      item.send("#{attribute}=", (item_constants_module::DATA_INTERPRETOR[attribute] || DEFAULT_DATA_INTERPRETOR).call(row_data[index], options))
    end
  end

  def validate_task_template_references(task_template_rows, reference_template_rows, reference_klass, reference_index_in_task_template)
    allowed_reference_template_titles = reference_template_rows.map{ |reference_template_row| reference_template_row[reference_klass::FIELD_HEADER_ORDER.index(:title)].presence }.compact.uniq
    reference_template_titles_present = task_template_rows.map{ |task_template_row| task_template_row[TaskTemplate::FIELD_HEADER_ORDER.index(reference_index_in_task_template)].presence }.compact.uniq
    (reference_template_titles_present - allowed_reference_template_titles).blank?
  end

  def validate_task_template_and_facilitation_message_roles
    allowed_roles = @custom_role_map.keys + ROLE_MAPPING.keys
    roles_present = (get_task_template_roles + get_facilitation_message_roles).map(&:downcase).uniq
    (roles_present - allowed_roles).blank?
  end

  def get_task_template_roles
    @task_template_rows.map{ |task_template_row| task_template_row[TaskTemplate::FIELD_HEADER_ORDER.index(:role_id)].presence }.compact
  end

  def get_facilitation_message_roles
    @facilitation_message_rows.map{ |facilitation_message_row| facilitation_message_row[FacilitationMessageTemplate::FIELD_HEADER_ORDER.index(:role_names)].to_s.split(ROLE_DELIMITER).map{ |role| role.strip.presence } }.flatten.compact
  end

end