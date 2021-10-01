require_relative './../../test_helper.rb'

class OrganizationDashboardServiceTest < ActiveSupport::TestCase
  def test_get_item_counts_for_admin
    program = programs(:albers)

    groups(:mygroup).mentoring_model_tasks.create!(:title => 'some text', :required => true, :status => MentoringModel::Task::Status::TODO, :due_date => 1.week.ago)
    create_admin_message(:sender => members(:f_student))
    create_flag
    topic = create_topic
    create_post(topic: topic, published: false)
    group = groups(:mygroup).project_requests.create!(message: "Hi", sender: users(:student_1), program: program)
    groups(:drafted_group_1).update_attribute(:status, Group::Status::PROPOSED)


    item_counts_for_admin = OrganizationDashboardService.new(programs(:org_primary)).get_item_counts_for_admin

    assert program.groups.active.present?
    assert program.groups.active.with_overdue_tasks.present?
    assert_equal program.groups.active.size, item_counts_for_admin[:mentoring_connections][:all][program.id]
    assert_equal program.groups.active.with_overdue_tasks.size, item_counts_for_admin[:mentoring_connections][:overdue][program.id]
    assert_equal program.groups.active.size - program.groups.active.with_overdue_tasks.size, item_counts_for_admin[:mentoring_connections][:ontrack][program.id]

    users_per_role = item_counts_for_admin[:users_per_role][program.id].group_by(&:role_id)
    program.roles.non_administrative.each do |role|
      assert_equal program.send("#{role.name}_users").count, users_per_role[role.id].first.users_count
    end

    assert program.admin_message_receivers.received.unread.present?
    assert_equal program.admin_messages_unread_count, item_counts_for_admin[:unread_admin_messages][program.id]

    assert program.flags.unresolved.present?
    assert_equal program.unresolved_flagged_content_count, item_counts_for_admin[:unresolved_flagged_content][program.id]

    assert program.posts.unpublished.present?
    assert_equal program.posts.unpublished.size, item_counts_for_admin[:unpublished_posts][program.id]

    assert program.membership_requests.not_joined_directly.pending.present?
    assert_equal program.membership_requests.not_joined_directly.pending.count, item_counts_for_admin[:pending_membership_requests][program.id]

    assert program.project_requests.active.present?
    assert_equal program.project_requests.active.count, item_counts_for_admin[:pending_project_requests][program.id]

	assert program.groups.proposed.present?
    assert_equal program.groups.proposed.count, item_counts_for_admin[:proposed_groups][program.id]
  end

  def test_get_item_counts_for_admin_for_portal
    program = programs(:primary_portal)
    program.flags.create!(user_id: users(:portal_employee).id, reason: "Privacy", content_type: Article.name, status: Flag::Status::UNRESOLVED)

    forum = forums(:employee_forum)
    topic = create_topic(:title => "title", :forum => forum, :user => users(:portal_employee))

    # Create a post in that topic
    post = create_post(:user => users(:portal_employee), :topic => topic, :attachment => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :published => false)

    program.roles.find_by(name: RoleConstants::EMPLOYEE_NAME).update_attributes(membership_request: true)
    member = members(:nch_mentor)
    MembershipRequest.create!(:member => member, :email => member.email, :program => programs(:primary_portal), :first_name => member.first_name, :last_name => member.last_name, :role_names => [RoleConstants::EMPLOYEE_NAME])

    item_counts_for_admin = OrganizationDashboardService.new(programs(:org_nch)).get_item_counts_for_admin
    assert_false program.groups.active.present?
    assert_nil item_counts_for_admin[:mentoring_connections][:all][program.id]
    assert_nil item_counts_for_admin[:mentoring_connections][:overdue][program.id]
    assert_nil item_counts_for_admin[:mentoring_connections][:ontrack][program.id]

    users_per_role = item_counts_for_admin[:users_per_role][program.id].group_by(&:role_id)
    program.roles.non_administrative.each do |role|
      assert_equal program.send("#{role.name}_users").count, users_per_role[role.id].first.users_count
    end

    assert program.admin_message_receivers.received.unread.present?
    assert_equal program.admin_messages_unread_count, item_counts_for_admin[:unread_admin_messages][program.id]
    assert_equal 1, item_counts_for_admin[:unresolved_flagged_content][program.id]
    assert_equal 1, item_counts_for_admin[:unpublished_posts][program.id]
    assert_equal 1, item_counts_for_admin[:pending_membership_requests][program.id]
    assert_false program.project_requests.active.present?
    assert_false program.project_based?
    assert_nil item_counts_for_admin[:pending_project_requests][program.id]
    assert_nil item_counts_for_admin[:proposed_groups][program.id]
  end
end