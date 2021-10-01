class Group::MentoringModelUpdater
  attr_accessor :group, :program, :mentoring_model

  def initialize(group, locale)
    @group = group
    @program = group.program
    @mentoring_model = group.mentoring_model
    @current_locale = locale
  end

  def sync
    ActiveRecord::Base.transaction do
      @group = Group.where(id: group.id).lock(true).first
      return if !group.active? || group.version >= mentoring_model.version
      Globalize.with_locale(@current_locale) do
        set_common_instance_vars
        patch_tasks
        patch_goals
        patch_milestones
        group.set_task_positions
        group.set_milestones_positions
        update_group_version
      end
    end
  end

  private

  def set_common_instance_vars
    [:milestone, :goal].each do |sym|
      instance_variable_set :"@#{sym}_template_id_to_#{sym}_mapper", {}
      instance_variable_set :"@#{sym}_id_to_#{sym}_template_mapper", {}
      instance_variable_set :"@#{sym}_id_to_#{sym}_mapper", {}
      instance_variable_set :"@#{sym}_templates", mentoring_model.send(:"mentoring_model_#{sym}_templates")
      instance_variable_set :"@#{sym}s", group.send(:"mentoring_model_#{sym}s").from_template

      obj_template_id_to_obj_mapper = instance_variable_get :"@#{sym}_template_id_to_#{sym}_mapper"
      obj_id_to_obj_template_mapper = instance_variable_get :"@#{sym}_id_to_#{sym}_template_mapper"
      obj_id_to_obj_mapper = instance_variable_get :"@#{sym}_id_to_#{sym}_mapper"
      obj_templates = instance_variable_get :"@#{sym}_templates"
      objs = instance_variable_get :"@#{sym}s"

      obj_templates.each do |obj_template|
        obj_template_id_to_obj_mapper[obj_template.id] = objs.find{|o| o.send(:"mentoring_model_#{sym}_template_id") == obj_template.id}
      end
      objs.each do |obj|
        obj_id_to_obj_template_mapper[obj.id] = obj_templates.find{|ot| ot.id == obj.send(:"mentoring_model_#{sym}_template_id")}
        obj_id_to_obj_mapper[obj.id] = obj
      end
    end
  end

  def set_task_specific_instance_vars
    @mentoring_model_task_templates = mentoring_model.mentoring_model_task_templates
    @mentoring_model_tasks = group.mentoring_model_tasks.from_template.includes([mentoring_model_goal: :translations, connection_membership: [user: [member: []]], mentoring_model_task_template: []]).to_a
    @task_template_id_to_task_template_mapper = {}
    @task_template_id_to_task_mapper = {}
    @task_id_to_task_template_mapper = {}
    @task_id_to_task_mapper = {}

    @mentoring_model_task_templates.each do |task_template|
      @task_template_id_to_task_template_mapper[task_template.id] = task_template
      @task_template_id_to_task_mapper[task_template.id] = @mentoring_model_tasks.select { |t| t.mentoring_model_task_template_id == task_template.id }
    end
    @mentoring_model_tasks.each do |task|
      @task_id_to_task_template_mapper[task.id] = @mentoring_model_task_templates.find { |tt| tt.id == task.mentoring_model_task_template_id }
      @task_id_to_task_mapper[task.id] = task
    end
  end

  def patch_milestones_or_goals(sym)
    obj_template_id_to_obj_mapper = instance_variable_get :"@#{sym}_template_id_to_#{sym}_mapper"
    obj_id_to_obj_template_mapper = instance_variable_get :"@#{sym}_id_to_#{sym}_template_mapper"
    obj_id_to_obj_mapper = instance_variable_get :"@#{sym}_id_to_#{sym}_mapper"
    obj_templates = instance_variable_get :"@#{sym}_templates"
    objs = instance_variable_get :"@#{sym}s"

    # Deletions of template objs
    objs.each do |obj|
      if obj_id_to_obj_template_mapper[obj.id].nil?
        obj.destroy
        obj_id_to_obj_template_mapper.delete(obj.id)
      end
    end
    obj_id_to_obj_template_mapper_to_edit = obj_id_to_obj_template_mapper.clone

    # Additions in template
    obj_templates.each do |obj_template|
      if obj_template_id_to_obj_mapper[obj_template.id].nil?
        obj = group.send(:"mentoring_model_#{sym}s").new
        obj.title = obj_template.title
        obj.description = obj_template.description
        obj.from_template = true
        obj.template_version = obj_template.version_number
        if sym == :goal
          obj.mentoring_model_goal_template_id = obj_template.id
        elsif sym == :milestone
          obj.mentoring_model_milestone_template_id = obj_template.id
          obj.position = obj_template.position
        end
        obj.save!
        MentoringModelUtils.copy_translatable_attributes(obj_template, obj, [:title, :description])

        obj_template_id_to_obj_mapper[obj_template.id] = obj
        obj_id_to_obj_template_mapper[obj.id] = obj_template

        tasks_to_update = obj_template.send("#{sym == :milestone ? "mentoring_model_" : ""}task_templates").map { |task_template| @task_template_id_to_task_mapper[task_template.id] }
        tasks_to_update.flatten.each { |task| task.send("#{sym}_id=", obj.id); task.save }
      end
    end

    # Updating title, description changes
    objs = group.send(:"mentoring_model_#{sym}s").reload
    obj_id_to_obj_template_mapper_to_edit.each do |obj_id, obj_template|
      obj = obj_id_to_obj_mapper[obj_id]
      if obj.template_version < obj_template.version_number
        obj.update_attributes!(
          title: obj_template.title,
          description: obj_template.description,
          template_version: obj_template.version_number
        )
      end
    end
  end

  def patch_milestones
    patch_milestones_or_goals(:milestone)
  end

  def patch_goals
    patch_milestones_or_goals(:goal)
  end

  def patch_tasks
    set_task_specific_instance_vars
    detect_improper_structures!(@mentoring_model_task_templates)
    scrub_tasks_without_template
    set_due_dates_for_task_templates(@mentoring_model_task_templates)
    @mentoring_model_task_templates.each do |task_template|
      detect_and_patch_diff!(task_template, @task_template_id_to_task_mapper[task_template.id])
    end
  end

  def detect_improper_structures!(task_templates)
    stack = task_templates.select { |tt| tt.associated_id.nil? }
    visited = {}
    until stack.empty?
      template = stack.pop
      if visited[template.id]
        # V2 timeline tasks are required to be a DAG
        raise "Invalid configuration detected : Not a directed acyclic graph"
      else
        task_templates.select { |tt| tt.associated_id == template.id }.each { |tt| stack.push(tt) }
        visited[template.id] = true
      end
    end
    raise "Invalid configuration detected : disjoint cycles found" if visited.size != task_templates.size
  end

  def scrub_tasks_without_template
    @mentoring_model_tasks.each do |task|
      if task.mentoring_model_task_template.nil?
        task.destroy
        @task_id_to_task_mapper.delete(task.id)
        @task_id_to_task_template_mapper.delete(task.id)
      end
    end
  end

  def set_due_dates_for_task_templates(task_templates)
    queue = [task_templates.select { |tt| tt.associated_id.nil? }.each { |tt| tt.due_date = group.published_at } ]
    visited = {}

    until queue.empty?
      list = queue.shift
      list.each do |template|
        unless visited[template.id]
          if template.specific_date
            template.due_date = template.specific_date
          else
            template.due_date += template.duration.days
          end
          queue << task_templates.select { |tt| tt.associated_id == template.id }.each { |tt| tt.due_date = template.due_date }
          visited[template.id] = true
        end
      end
    end
  end

  def detect_and_patch_diff!(task_template, tasks)
    task_template_attributes = task_template.attributes.pick("title", "description", "required", "action_item_type", "action_item_id")
    task_specific_attributes = {
      "milestone_id" => @milestone_template_id_to_milestone_mapper[task_template.milestone_template_id].try(:id),
      "goal_id" =>  @goal_template_id_to_goal_mapper[task_template.goal_template_id].try(:id),
      "template_version" => task_template.version_number
    }
    task_specific_attributes.merge!("due_date" => task_template.due_date) if task_template.required?
    memberships_for_task_template = get_memberships(task_template.role_id)

    if tasks.size == 0
      task_specific_attributes.merge!(task_template_attributes)
      add_tasks(task_template, task_specific_attributes, memberships_for_task_template)
    else
      update_existing_tasks(task_template, tasks, memberships_for_task_template, task_specific_attributes, task_template_attributes)
    end
  end

  def get_memberships(role_id)
    return [nil] if role_id.nil?

    if @memberships_hash.nil?
      roles = program.roles.select([:id, :name]).for_mentoring_models
      memberships = group.memberships
      @memberships_hash = {}
      roles.each do |role|
        @memberships_hash[role.id] = memberships.select do |membership|
          membership.role_id == role.id
        end
      end
    end
    @memberships_hash[role_id] || (raise "Invalid task connection role encountered")
  end

  def add_tasks(task_template, attributes, connection_memberships)
    connection_memberships.each do |connection_membership|
      mentoring_model_task = group.mentoring_model_tasks.new(attributes)
      mentoring_model_task.connection_membership_id = connection_membership.try(:id)
      mentoring_model_task.status = MentoringModel::Task::Status::TODO
      mentoring_model_task.from_template = true
      mentoring_model_task.mentoring_model_task_template_id = task_template.id
      mentoring_model_task.unassigned_from_template = connection_membership.nil?
      mentoring_model_task.skip_observer = true
      mentoring_model_task.skip_es_indexing = true
      mentoring_model_task.updated_from_connection = false
      mentoring_model_task.save!
      MentoringModelUtils.copy_translatable_attributes(task_template, mentoring_model_task, [:title, :description])

      @task_template_id_to_task_mapper[task_template.id] << mentoring_model_task
      @task_id_to_task_mapper[mentoring_model_task.id] = mentoring_model_task
      @task_id_to_task_template_mapper[mentoring_model_task.id] = task_template
      @mentoring_model_tasks << mentoring_model_task
    end
    DelayedEsDocument.delayed_update_es_document(Group, group.id) if group.present?
  end

  def update_existing_tasks(task_template, tasks, memberships_for_task_template, task_specific_attributes, task_template_attributes)
    tasks_with_owner_changed = []
    memberships_with_tasks_already = tasks.collect(&:connection_membership)
    task_template_role_id = task_template.role_id
    translatable_attribute_names = MentoringModel::Task.translated_attribute_names
    role_id_updated = false

    if tasks.size == 0
      add_tasks(task_template, task_specific_attributes.merge!(task_template_attributes), memberships_for_task_template)
    else
      tasks.each do |task|
        if task.template_version < task_template.version_number || (task_template.required? && !task.due_date_altered && task.due_date != task_template.due_date)
          updated_task_template_attributes = attributes_changed_between_versions(task_template, task.template_version, task_template.version_number)
          task_specific_attributes__cloned = task_specific_attributes.dup
          task_specific_attributes__cloned.merge!(task_template_attributes.pick(*updated_task_template_attributes))
          task_specific_attributes__cloned = task_specific_attributes__cloned.except("due_date") if task.due_date_altered

          translatable_attributes = task_specific_attributes__cloned.pick(*translatable_attribute_names)
          non_translatable_attributes = task_specific_attributes__cloned.except(*translatable_attribute_names)

          # If the associated survey is changed, undo the task status
          task.status = MentoringModel::Task::Status::TODO if task_template.action_item_id != task.action_item_id
          task.updated_from_connection = false

          role_id_updated ||= updated_task_template_attributes.include?("role_id")
          # Completed tasks are neither re-assigned nor removed
          if task.todo? && role_id_updated
            assignee_updated = (task_template_role_id.blank? && task.connection_membership.present?)
            assignee_updated ||= (task_template_role_id.present? && (task.connection_membership.try(:role_id) != task_template_role_id))
          end

          if assignee_updated
            tasks_with_owner_changed << task
          else
            task.update_attributes!(non_translatable_attributes)
            if translatable_attributes.any?
              translation = task.translations.find { |translation| translation.locale == ::Globalize.locale }
              translation ||= task.translations.new(locale: ::Globalize.locale)
              translatable_attributes.each { |name, value| translation[name] = value }
              translation.save!
            end
          end
        end
      end

      # Adding tasks for missing memberships in case of role_id update
      add_tasks(task_template, task_specific_attributes.merge!(task_template_attributes), memberships_for_task_template - memberships_with_tasks_already) if role_id_updated
      # Removing the assignee-changed tasks
      scrub_assignee_changed_tasks(tasks_with_owner_changed)
    end
  end

  def attributes_changed_between_versions(object, from_version, to_version)
    versions = object.versions.last(to_version - from_version)
    versions.collect(&:modifications).collect(&:keys).flatten.uniq
  end

  def scrub_assignee_changed_tasks(tasks_with_owner_changed)
    tasks_with_owner_changed.each do |task_with_owner_changed|
      task_with_owner_changed.destroy
      @task_id_to_task_mapper.delete(task_with_owner_changed.id)
      @task_id_to_task_template_mapper.delete(task_with_owner_changed.id)
      @task_template_id_to_task_mapper[task_with_owner_changed.mentoring_model_task_template_id].delete(task_with_owner_changed)
    end
  end

  def update_group_version
    group.skip_observer = true
    group.version = mentoring_model.version
    group.save!
  end
end