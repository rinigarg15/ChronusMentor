require_relative './../../test_helper.rb'

class MentoringModelObserverTest < ActiveSupport::TestCase

  def test_before_create
    program = programs(:albers)
    assert_false program.allow_one_to_many_mentoring?

    MentoringModel.any_instance.expects(:populate_default_forum_help_text).once
    mentoring_model = program.mentoring_models.create!(title: "New MM", mentoring_period: Program::DEFAULT_MENTORING_PERIOD)
    assert mentoring_model.allow_messaging?
    assert_false mentoring_model.allow_forum?

    allow_one_to_many_mentoring_for_program(program)
    MentoringModel.any_instance.expects(:populate_default_forum_help_text).once
    mentoring_model = program.mentoring_models.create!(title: "New MM 2", mentoring_period: Program::DEFAULT_MENTORING_PERIOD)
    assert_false mentoring_model.allow_messaging?
    assert mentoring_model.allow_forum?

    MentoringModel.any_instance.expects(:populate_default_forum_help_text).never
    mentoring_model = program.mentoring_models.new(title: "New MM 3", mentoring_period: Program::DEFAULT_MENTORING_PERIOD)
    mentoring_model.prevent_default_setting = true
    mentoring_model.save!
    assert mentoring_model.allow_messaging?
    assert_false mentoring_model.allow_forum?
  end

  def test_after_create
    program = programs(:albers)
    roles_hash = program.roles.group_by(&:name)
    created_mentoring_model = nil
    assert_difference "ObjectRolePermission.count", 10 do
      assert_difference "MentoringModel.count" do
        created_mentoring_model = create_mentoring_model(title: "House Of Cards", skip_default_permissions: false)
      end
    end

    assert created_mentoring_model.should_sync
    assert_equal 2, program.reload.mentoring_models.count
    created_mentoring_model = program.mentoring_models.first

    assert created_mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_engagement_surveys?", roles_hash[RoleConstants::ADMIN_NAME].first)

    assert created_mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false created_mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false created_mentoring_model.send("can_manage_mm_engagement_surveys?", roles_hash[RoleConstants::MENTOR_NAME].first)

    assert created_mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert created_mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false created_mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false created_mentoring_model.send("can_manage_mm_engagement_surveys?", roles_hash[RoleConstants::STUDENT_NAME].first)

    assert_no_difference "ObjectRolePermission.count" do
      created_mentoring_model = create_mentoring_model
    end
  end

  def test_after_save
    enable_project_based_engagements!
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:allow_messaging, false)

    pending_group = groups(:group_2)
    pending_group.status = Group::Status::PENDING
    published_group = groups(:mygroup)
    unpublished_group = groups(:drafted_group_1)
    closed_group = groups(:group_4)
    published_group.update_attribute(:mentoring_model_id, mentoring_model.id)
    pending_group.update_attribute(:mentoring_model_id, mentoring_model.id)
    unpublished_group.update_attribute(:mentoring_model_id, mentoring_model.id)
    closed_group.update_attribute(:mentoring_model_id, mentoring_model.id)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, mentoring_model.group_ids)
    assert_false [pending_group, published_group, unpublished_group, closed_group].collect {|group| group.forum.present?}.uniq.first
    assert_difference "Forum.count", 3 do
      mentoring_model.allow_forum = true
      mentoring_model.save!
    end

    assert published_group.reload.forum.present?
    assert pending_group.reload.forum.present?
    assert_false unpublished_group.reload.forum.present?
    assert closed_group.reload.forum.present?
  end
end