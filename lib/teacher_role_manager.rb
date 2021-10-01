class TeacherRoleManager

  PERMISSIONS_TO_ADD = %w(
    write_article view_articles answer_question
    view_students view_mentors view_ra view_find_new_projects
    view_teachers ask_question follow_question rate_answer set_availability view_questions
  )

  DEFAULT_VIEWS_TO_UPDATE = [
    AbstractView::DefaultType::ALL_USERS,
    AbstractView::DefaultType::ACCEPTED_BUT_NOT_JOINED,
    AbstractView::DefaultType::REGISTERED_BUT_NOT_ACTIVE
  ]

  def initialize(program)
    @program = program
    @old_mentoring_role_ids = @program.mentoring_role_ids
    @role_name = RoleConstants::TEACHER_NAME
  end

  def create_third_role
    begin
      ActiveRecord::Base.transaction do
        role = create_role
        add_permissions(role)
        update_other_role_permissions
        add_object_role_permissions(role)
        add_default_questions_for(role)
        incorporate_admin_views
      end
      true
    rescue => exception
      Airbrake.notify(exception)
      false
    end
  end

  def remove_third_role
    begin
      ActiveRecord::Base.transaction do
        role = @program.find_role(@role_name)
        role.destroy
        update_other_role_permissions(false)
        incorporate_admin_views(true)
      end
      true
    rescue => exception
      Airbrake.notify(exception)
      false
    end
  end

  private

  def incorporate_admin_views(only_non_editable = false)
    role_names = @program.roles.pluck(:name)
    admin_views = @program.admin_views.where(default_view: DEFAULT_VIEWS_TO_UPDATE)
    admin_views = admin_views.select { |admin_view| !admin_view.editable? } if only_non_editable
    admin_views.each do |admin_view|
      yaml_params = admin_view.filter_params_hash
      yaml_params[:roles_and_status][:role_filter_1] = { type: :include, roles: role_names }
      admin_view.filter_params = AdminView.convert_to_yaml(yaml_params)
      admin_view.save!
    end
  end

  def add_default_questions_for(role)
    profile_questions = ProfileQuestion.where(organization_id: @program.parent_id).default_questions
    profile_questions.each do |profile_question|
      profile_question.role_questions.create!(
        role_id: role.id,
        required: true,
        filterable: true,
        in_summary: false,
        available_for: RoleQuestion::AVAILABLE_FOR::BOTH,
        private: RoleQuestion::PRIVACY_SETTING::ALL
      )
    end
  end

  def add_object_role_permissions(new_role)
    @program.mentoring_models.includes(:object_role_permissions).each do |mentoring_model|
      object_permission_ids = []
      mentoring_model.object_role_permissions.each do |object_role_permission|
        if @old_mentoring_role_ids.include?(object_role_permission.role_id)
          object_permission_ids << object_role_permission.object_permission_id
        end
      end
      object_permission_ids.uniq.each do |object_permission_id|
        mentoring_model.object_role_permissions.create!(
          role_id: new_role.id,
          object_permission_id: object_permission_id
        )
      end
    end
  end

  def create_role
    @program.roles.create!(
      name: @role_name,
      default: nil,
      administrative: false,
      for_mentoring: true
    )
  end

  def add_permissions(role)
    Permission.create_default_permissions
    PERMISSIONS_TO_ADD.each { |permission_name| role.add_permission(permission_name) }
  end

  def update_other_role_permissions(add = true)
    permission_method = add ? :add_permission : :remove_permission
    @program.roles.each { |role| role.send(permission_method, 'view_teachers') }
    admin_role = @program.find_role(RoleConstants::ADMIN_NAME)
    admin_role.send(permission_method, RoleConstants::InviteRolePermission::Permission[RoleConstants::InviteRolePermission::RoleName::TEACHER_NAME])
  end
end