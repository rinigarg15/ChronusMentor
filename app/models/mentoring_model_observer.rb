class MentoringModelObserver < ActiveRecord::Observer

  def before_create(mentoring_model)
    mentoring_model.should_sync = true
    program = mentoring_model.program

    if program.present? && !mentoring_model.prevent_default_setting
      mentoring_model.allow_messaging = !program.allow_one_to_many_mentoring?
      mentoring_model.allow_forum = program.allow_one_to_many_mentoring?
      mentoring_model.populate_default_forum_help_text
    end
  end

  def after_create(mentoring_model)
    return if mentoring_model.skip_default_permissions || mentoring_model.hybrid?
    admin_role_object = nil
    end_user_role_objects = nil
    roles = mentoring_model.program.roles.for_mentoring_models
    admin_role_object = roles.select(:id).with_name([RoleConstants::ADMIN_NAME])
    end_user_role_objects = roles.select(:id).for_mentoring
    ObjectPermission::MentoringModel::DEFAULTS[:admin_role].each do |permission|
      mentoring_model.send("allow_#{permission}!", admin_role_object)
    end
    ObjectPermission::MentoringModel::DEFAULTS[:user_role].each do |permission|
      mentoring_model.send("allow_#{permission}!", end_user_role_objects)
    end
  end

  def after_save(mentoring_model)
    if mentoring_model.saved_change_to_allow_forum? && mentoring_model.allow_forum?
      mentoring_model.groups.open_or_closed.includes(:forum, :mentoring_model).each do |group|
        group.create_group_forum
      end
    end
    reindex_followups(mentoring_model)
  end

  private

  def reindex_followups(mentoring_model)
    MentoringModel.es_reindex(mentoring_model)
  end
end