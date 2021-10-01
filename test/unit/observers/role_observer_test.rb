require_relative './../../test_helper.rb'

class RoleObserverTest < ActiveSupport::TestCase
  def test_after_create
    Role.any_instance.expects(:set_default_customized_term).at_least(1)
    assert_difference 'Permission.count' do
      role = programs(:albers).roles.new(name: 'new_role')
      role.save!
    end
    assert_equal "view_" + "new_roles".pluralize, Permission.last.name
  end

  def test_slot_config_after_create
    organization = programs(:org_primary)
    career_based_program = programs(:albers)
    project_based_program = programs(:pbe)

    [organization, career_based_program, project_based_program].each do |abstract_program|
      role = abstract_program.roles.create!(name: "new_role_one")
      assert_false role.slot_config_enabled?
    end

    [organization, career_based_program].each do |abstract_program|
      role = abstract_program.roles.create!(name: "new_role_two", for_mentoring: true)
      assert_false role.slot_config_enabled?
    end

    role = project_based_program.roles.create!(name: "new_role_three", for_mentoring: true)
    assert role.slot_config_optional?
  end

  def test_observers_reindex_es
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(QaQuestion, qa_questions(:what, :why).map(&:id) + 15.times.map { |i| qa_questions("qa_question_#{i + 100}").id } + [qa_questions(:question_for_stopwords_test).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).never.with(User, any_parameters) # Dont call if the role is just getting created since there wont be any role references to connect to users or
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(Article, articles(:economy, :india, :kangaroo, :delhi).map(&:id))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(Group, groups(:mygroup, :group_2, :group_3, :group_4, :group_5, :group_inactive, :old_group, :drafted_group_1, :drafted_group_2, :drafted_group_3).map(&:id))
    new_role = programs(:albers).roles.new(name: 'new_role')
    new_role.save!

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(User, [users(:f_admin_pbe).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, 5.times.map { |i| groups("group_pbe_#{i}").id } + [groups(:group_pbe).id] + 4.times.map { |i| groups("proposed_group_#{i + 1}").id } + groups(:rejected_group_1, :rejected_group_2, :withdrawn_group_1, :drafted_pbe_group).map(&:id))
    role = programs(:pbe).find_role(RoleConstants::ADMIN_NAME)
    role.update_attribute(:name, "Hello World")
    new_role.destroy
  end

  def test_change_to_max_connections_limit
    role = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME)
    user_id_role_id_hash = {}
    role.users.pluck(:id).each{ |user_id| user_id_role_id_hash[user_id] = role.id }
    ProjectRequest.expects(:close_pending_requests_if_required).with(user_id_role_id_hash)
    role.update_attributes!(max_connections_limit: 1)
    role.update_attributes!(max_connections_limit: 2)
    ProjectRequest.expects(:close_pending_requests_if_required).with(user_id_role_id_hash)
    role.update_attributes!(max_connections_limit: 1)
    role.update_attributes!(max_connections_limit: nil)
  end
end