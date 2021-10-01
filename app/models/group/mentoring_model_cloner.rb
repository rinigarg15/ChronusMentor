class Group::MentoringModelCloner
  attr_reader :group, :program, :memberships, :roles,
              :admin_role, :mentoring_model_task_templates, :mentoring_model

  def initialize(group, program, assignable_mentoring_model, memberships = [])
    @group = group
    @program = program
    @mentoring_model = assignable_mentoring_model
    @roles = program.roles.select([:id, :name]).for_mentoring_models
    @admin_role = @roles.find(&:admin?)
    memberships = memberships.collect{|m| m if Connection::Membership.exists?(m.id)}.compact
    @memberships = memberships.presence || @group.memberships
    @mentoring_model_task_templates = mentoring_model.mentoring_model_task_templates
  end

  def copy_mentoring_model_objects(options = {})
    ActiveRecord::Base.transaction do
      set_mentoring_model!(options)
      copy_permissions unless options[:skip_save]
      copy_goal_templates unless options[:skip_save]
      copy_milestone_templates(options)
      copy_task_templates unless options[:skip_save]
      DelayedEsDocument.delayed_update_es_document(Group, @group.id) if @group.present?
    end
  end

  def set_mentoring_model!(options = {})
    group.skip_observer = true
    group.mentoring_model_id = mentoring_model.id
    group.expiry_time = Time.now + (@mentoring_model.mentoring_period / 1.day).days
    group.save! unless options[:skip_save]
  end

  def copy_permissions
    group.copy_object_role_permissions_from!(mentoring_model, roles: roles)
  end

  def copy_task_templates
    return unless can_copy?(ObjectPermission::MentoringModel::TASK)
    @id_to_task_template_mapper = @mentoring_model_task_templates.group_by(&:id)
    @task_id_to_template_id_mapper = {}
    @new_mentoring_model_tasks = copy_task_attributes(@mentoring_model_task_templates)
    mentoring_model_tasks = group.mentoring_model_tasks
    @template_id_to_tasks_mapper = mentoring_model_tasks.group_by(&:mentoring_model_task_template_id)
    @mentoring_model_task_templates.each { |task_template| @template_id_to_tasks_mapper[task_template.id] ||= [] } 
    mentoring_model_tasks.each { |task| @task_id_to_template_id_mapper[task.id] = task.mentoring_model_task_template_id }
    compute_due_dates!
    group.set_task_positions
  end

  def copy_goal_templates
    return unless can_copy?(ObjectPermission::MentoringModel::GOAL)
    goal_templates = mentoring_model.mentoring_model_goal_templates
    @goal_template_id_to_goal_id_mapper = {}
    copy_goal_attributes(goal_templates)
  end

  def copy_milestone_templates(options = {})
    return unless can_copy?(ObjectPermission::MentoringModel::MILESTONE)
    milestone_templates = mentoring_model.mentoring_model_milestone_templates
    @milestone_template_id_to_milestone_id_mapper = {}
    copy_milestone_attributes(milestone_templates, options)
  end

  def copy_template_tasks_for_memberships
    @milestone_template_id_to_milestone_id_mapper = {}
    @goal_template_id_goal_id_mapper = {}
    @group.mentoring_model_milestones.select("id, mentoring_model_milestone_template_id").each do |milestone|
      @milestone_template_id_to_milestone_id_mapper[milestone.mentoring_model_milestone_template_id] = milestone.id
    end
    @group.mentoring_model_goals.select("id, mentoring_model_goal_template_id").each do |goal|
      @goal_template_id_goal_id_mapper[goal.mentoring_model_goal_template_id] = goal.id
    end
    copy_task_templates
  end

  private

  def compute_due_dates!
    tasks_queue = [get_child_tasks_and_fill_due_date(nil, @group.published_at)]
    visited = {}
    until tasks_queue.empty?
      tasks_list = tasks_queue.shift
      tasks_list.select{|task| visited[task.id].blank? }.each do |task|
        if task.required? && @new_mentoring_model_tasks.include?(task)
          corresponding_task_template = corresponding_task_template(task)
          if corresponding_task_template.specific_date.present?
            task.due_date = corresponding_task_template.specific_date
          else
            task.due_date += corresponding_task_template.duration.days
          end
          task.skip_update_positions = true
          task.save!
        end
        tasks_queue << get_child_tasks_and_fill_due_date(@task_id_to_template_id_mapper[task.id], task.due_date)
        visited[task.id] = true
      end
    end
  end

  def get_child_tasks_and_fill_due_date(task_template_id, due_date)
    @mentoring_model_task_templates.select do |task_template|
      task_template.associated_id.eql?(task_template_id)
    end.map do |task_template|
      @template_id_to_tasks_mapper[task_template.id]
    end.flatten.map do |task|
      if @new_mentoring_model_tasks.include?(task)
        task.due_date = task.required? ? due_date : nil
        task.skip_observer = true
        task.skip_es_indexing = true
        task.save!
      end
      task
    end
  end

  def corresponding_task_template(mentoring_model_task)
    @id_to_task_template_mapper[@task_id_to_template_id_mapper[mentoring_model_task.id]].first
  end

  def copy_task_attributes(task_templates)
    new_mentoring_model_tasks = []
    task_templates.each do |task_template|
      existing_group_tasks = task_template.mentoring_model_tasks.where(group_id: group.id)
      membership_ids = existing_group_tasks.pluck(:connection_membership_id)
      connection_memberships = task_template.role_id.present? ? get_memberships(task_template.role_id) : [nil]
      connection_memberships.each do |connection_membership|
        unless (connection_membership.nil? && existing_group_tasks.present?) || (connection_membership.present? && membership_ids.include?(connection_membership.id))
          mentoring_model_task = @group.mentoring_model_tasks.new(task_template.attributes.pick("required", "title", "description", "position", "action_item_type","action_item_id"))
          mentoring_model_task.connection_membership_id = connection_membership.try(:id)
          mentoring_model_task.goal_id = @goal_template_id_to_goal_id_mapper[task_template.goal_template_id] if !@mentoring_model.manual_progress_goals? && @goal_template_id_to_goal_id_mapper.present?
          mentoring_model_task.milestone_id = @milestone_template_id_to_milestone_id_mapper[task_template.milestone_template_id] if @milestone_template_id_to_milestone_id_mapper.present?
          mentoring_model_task.status = MentoringModel::Task::Status::TODO
          mentoring_model_task.from_template = true
          mentoring_model_task.template_version = task_template.version_number
          mentoring_model_task.mentoring_model_task_template_id = task_template.id
          mentoring_model_task.skip_observer = true
          mentoring_model_task.skip_es_indexing = true
          mentoring_model_task.skip_due_date_validation = true
          mentoring_model_task.unassigned_from_template = connection_membership.nil?
          mentoring_model_task.save!
          MentoringModelUtils.copy_translatable_attributes(task_template, mentoring_model_task, [:title, :description])
          mentoring_model_task.skip_due_date_validation = false
          new_mentoring_model_tasks << mentoring_model_task
        end
      end
    end
    new_mentoring_model_tasks
  end

  def copy_goal_attributes(goal_templates)
    goal_templates.each do |goal_template|
      mentoring_model_goal = @group.mentoring_model_goals.new(goal_template.attributes.pick("title", "description"))
      mentoring_model_goal.from_template = true
      mentoring_model_goal.template_version = goal_template.version_number
      mentoring_model_goal.mentoring_model_goal_template_id = goal_template.id
      mentoring_model_goal.save!
      MentoringModelUtils.copy_translatable_attributes(goal_template, mentoring_model_goal, [:title, :description])
      @goal_template_id_to_goal_id_mapper[goal_template.id] = mentoring_model_goal.id
    end
  end

  def copy_milestone_attributes(milestone_templates, options = {})
    milestone_templates.each do |milestone_template|
      mentoring_model_milestone = @group.mentoring_model_milestones.new(
        milestone_template.attributes.pick("title", "description").merge(
          from_template: true,
          template_version: milestone_template.version_number,
          mentoring_model_milestone_template_id: milestone_template.id,
          position: milestone_template.position
        )
      )
      mentoring_model_milestone.save! unless options[:skip_save]
      MentoringModelUtils.copy_translatable_attributes(milestone_template, mentoring_model_milestone, [:title, :description], options)
      @milestone_template_id_to_milestone_id_mapper[milestone_template.id] = mentoring_model_milestone.id
    end
  end

  def get_memberships(role_id)
    memberships.select do |membership|
      membership.role_id == role_id
    end
  end

  def can_copy?(permission_name)
    mentoring_model.send("can_#{permission_name}?", @admin_role)
  end
end