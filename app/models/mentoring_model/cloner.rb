class MentoringModel::Cloner
  attr_accessor :milestone_template_mapper, :task_template_mapper, :goal_template_mapper
  attr_reader :new_mentoring_model

  def initialize(mentoring_model, title, target_program = nil)
    @mentoring_model = mentoring_model
    @source_program = @mentoring_model.program
    @target_program = target_program || @source_program
    @mentoring_model_title = title
    @new_mentoring_model = @target_program.mentoring_models.new(default: false, skip_default_permissions: true)
    @roles = @source_program.roles.select([:id, :name]).for_mentoring_models
    @milestone_template_mapper = {}
    @goal_template_mapper = {}
    @task_template_mapper = {}
    @options = get_options
  end

  def clone_objects!
    ActiveRecord::Base.transaction do
      set_mentoring_model
      clone_permissions
      if @mentoring_model.hybrid?
        clone_linked_templates
      else
        clone_goal_templates
        clone_milestone_templates
        clone_task_templates
        clone_facilitation_templates
      end
    end
    @new_mentoring_model
  end

  def clone_linked_templates
    @new_mentoring_model.children = @options[:mentoring_model_children].presence || @mentoring_model.children
  end

  def set_mentoring_model
    @new_mentoring_model.prevent_default_setting = true
    @new_mentoring_model.mentoring_period = @mentoring_model.mentoring_period
    @new_mentoring_model.title = @mentoring_model_title
    @new_mentoring_model.mentoring_model_type = @mentoring_model.mentoring_model_type
    @new_mentoring_model.allow_due_date_edit = @mentoring_model.allow_due_date_edit
    @new_mentoring_model.goal_progress_type = @mentoring_model.goal_progress_type
    @new_mentoring_model.allow_messaging = @mentoring_model.allow_messaging
    @new_mentoring_model.allow_forum = @mentoring_model.allow_forum
    @new_mentoring_model.forum_help_text = @mentoring_model.forum_help_text
    @new_mentoring_model.save!
    @new_mentoring_model
  end

  def clone_permissions
    @new_mentoring_model.copy_object_role_permissions_from!(@mentoring_model, roles: @roles, role_mapping: @options[:role_mapping])
  end

  # TODO:: Each of the methods below require the mentoring_model to be set etc.
  # These methods needs to be refactored such that it can be executed independently.
  # Couldn't do it without making the code messy :(
  def clone_goal_templates
    @mentoring_model.mentoring_model_goal_templates.each do |goal_template|
      new_goal_template = @new_mentoring_model.mentoring_model_goal_templates.new(
        title: goal_template.title, description: goal_template.description
      )
      new_goal_template.skip_increment_version_and_sync_trigger = true
      new_goal_template.save!
      MentoringModelUtils.copy_translatable_attributes(goal_template, new_goal_template, [:title, :description])
      goal_template_mapper[goal_template.id] = new_goal_template
    end
  end

  # This and the above method are exactly similar. Intentionally not refactoring as both are different models,
  # and there is a high chance of new columns added to either of them.
  def clone_milestone_templates
    @mentoring_model.mentoring_model_milestone_templates.each do |milestone_template|
      new_milestone_template = @new_mentoring_model.mentoring_model_milestone_templates.new(
        title: milestone_template.title, description: milestone_template.description, position: milestone_template.position
      )
      new_milestone_template.skip_increment_version_and_sync_trigger = true
      new_milestone_template.save!
      MentoringModelUtils.copy_translatable_attributes(milestone_template, new_milestone_template, [:title, :description])
      milestone_template_mapper[milestone_template.id] = new_milestone_template
    end
  end

  def clone_task_templates
    old_task_templates = @mentoring_model.mentoring_model_task_templates
    old_task_templates.each do |task_template|
      role_id, action_item_id = get_role_and_action_item_ids(task_template)
      new_task_template = @new_mentoring_model.mentoring_model_task_templates.new(
        required: task_template.required,
        title: task_template.title,
        description: task_template.description,
        duration: task_template.duration,
        action_item_type: task_template.action_item_type,
        action_item_id: action_item_id,
        role_id: role_id,
        milestone_template_id: milestone_template_mapper[task_template.milestone_template_id].try(:id),
        goal_template_id: goal_template_mapper[task_template.goal_template_id].try(:id),
        specific_date: task_template.specific_date
      )
      new_task_template.position = task_template.position
      new_task_template.skip_observer = true
      new_task_template.save!
      MentoringModelUtils.copy_translatable_attributes(task_template, new_task_template, [:title, :description])
      task_template_mapper[task_template.id] = new_task_template
    end
    set_associated_tasks!(old_task_templates)
  end

  def clone_facilitation_templates
    @mentoring_model.mentoring_model_facilitation_templates.each do |facilitation_template|
      new_facilitation_template = @new_mentoring_model.mentoring_model_facilitation_templates.new(
        subject: facilitation_template.subject,
        message: facilitation_template.message,
        send_on: facilitation_template.send_on,
        milestone_template_id: milestone_template_mapper[facilitation_template.milestone_template_id].try(:id),
        specific_date: facilitation_template.specific_date
      )
      new_facilitation_template.roles = get_roles(facilitation_template)
      new_facilitation_template.save!
      MentoringModelUtils.copy_translatable_attributes(facilitation_template, new_facilitation_template, [:subject, :message])
    end
  end

private

  def set_associated_tasks!(old_task_templates)
    old_task_templates.each do |task_template|
      new_task_template = task_template_mapper[task_template.id]
      new_task_template.associated_id = task_template_mapper[task_template.associated_id].try(:id)
      new_task_template.save!
    end
  end

  def cloning_across_programs?
    @target_program != @source_program
  end

  def get_role_and_action_item_ids(task_template)
    role_id = task_template.role_id
    action_item_id = task_template.action_item_id
    if cloning_across_programs?
      role_id = @options[:role_mapping][task_template.role].try(:id)
      action_item_id = @options[:survey_id_mapping][task_template.action_item_id] if task_template.is_engagement_survey_action_item?
    end
    [role_id, action_item_id]
  end

  def get_roles(facilitation_template)
    return facilitation_template.roles unless cloning_across_programs?
    facilitation_template.roles.map{ |role| @options[:role_mapping][role] }
  end

  def get_options
    return {} unless cloning_across_programs?
    @source_program = Program.where(id: @source_program.id).includes(:roles, surveys: :translations).first
    @target_program = Program.where(id: @target_program.id).includes(:roles, mentoring_models: :translations, surveys: :translations).first
    @mentoring_model = MentoringModel.where(id: @mentoring_model.id).includes(:translations, :children, mentoring_model_facilitation_templates: [:translations, :roles],  mentoring_model_task_templates: [:translations, :role]).first
    {
      mentoring_model_children: get_children,
      survey_id_mapping: get_survey_id_mapping,
      role_mapping: get_role_mappings
    }
  end

  def get_children
    return unless @mentoring_model.hybrid?
    @mentoring_model.children.map do |child_mentoring_model|
      target_child_mentoring_model = @target_program.mentoring_models.find{ |mm| mm.title == child_mentoring_model.title }
      raise "Child template #{child_mentoring_model.title} not found" unless target_child_mentoring_model.present?
      target_child_mentoring_model
    end
  end

  def get_survey_id_mapping
    survey_id_mapping = {}
    @mentoring_model.mentoring_model_task_templates.each do |task_template|
      next unless task_template.is_engagement_survey_action_item?
      source_survey, target_survey = get_source_and_target_surveys(task_template.action_item_id)
      raise "Survey #{source_survey.name} not found" unless target_survey.present?
      survey_id_mapping[source_survey.id] = target_survey.id
    end
    survey_id_mapping
  end

  def get_source_and_target_surveys(source_survey_id)
    source_survey = @source_program.surveys.find{ |survey| survey.id == source_survey_id }
    [source_survey, @target_program.surveys.find{ |survey| survey.name == source_survey.name && survey.type == EngagementSurvey.name }]
  end

  def get_role_mappings
    role_mappings = {}
    get_roles_to_map.each do |source_role|
      target_role = @target_program.roles.find{ |role| role.name == source_role.name }
      raise "Role #{source_role.name} not found" unless target_role.present?
      role_mappings[source_role] = target_role
    end
    role_mappings
  end

  def get_roles_to_map
    (@source_program.roles.select(&:administrative) + @mentoring_model.mentoring_model_facilitation_templates.collect(&:roles).flatten + @mentoring_model.mentoring_model_task_templates.collect(&:role)).compact.uniq
  end
end