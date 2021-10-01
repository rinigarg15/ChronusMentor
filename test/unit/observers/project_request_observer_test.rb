require_relative './../../test_helper.rb'

class ProjectRequestObserverTest < ActiveSupport::TestCase
  def test_create_not_for_display_recent_activity
    project_request = ProjectRequest.last
    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        ProjectRequestObserver.create_not_for_display_recent_activity(project_request.id, RecentActivityConstants::Type::PROJECT_REQUEST_SENT)
      end
    end

    project_request_ra = RecentActivity.last
    assert_equal project_request, project_request_ra.ref_obj
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_SENT, project_request_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal project_request.group, connection_activity.group
  end

  def test_after_create
    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        @project_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
      end
    end

    project_request_ra = RecentActivity.last
    assert_equal @project_request, project_request_ra.ref_obj
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_SENT, project_request_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal @project_request.group, connection_activity.group
  end

  def test_after_update_accepted
    teacher_role = programs(:pbe).roles.find_by(name: "teacher")
    users(:f_student_pbe).update_roles(["teacher"])
    @project_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id, sender_role_id: teacher_role.id)
    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        @project_request.mark_accepted(users(:f_admin_pbe))
      end
    end

    project_request_ra = RecentActivity.last
    assert_equal @project_request, project_request_ra.ref_obj
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED, project_request_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal @project_request.group, connection_activity.group
  end

  def test_after_update_rejected
    @project_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        @project_request.status = AbstractRequest::Status::REJECTED
        @project_request.receiver = users(:f_admin_pbe)
        @project_request.save!
      end
    end

    project_request_ra = RecentActivity.last
    assert_equal @project_request, project_request_ra.ref_obj
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED, project_request_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal @project_request.group, connection_activity.group
  end

  def test_es_reindexing
    project_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
    DelayedEsDocument.expects(:delayed_update_es_document).times(1).with(ProjectRequest, project_request.id)
    DelayedEsDocument.expects(:delayed_update_es_document).times(2).with(Group, groups(:group_pbe_1).id)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(4).with(Group, [groups(:group_pbe_1).id])
    project_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    project_request.destroy
  end
end