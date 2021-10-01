require_relative './../test_helper.rb'

class MembershipObserverTest < ActiveSupport::TestCase
  IMPORT_CSV_FILE_NAME = "mentoring_model/mentoring_model_import.csv"

  def test_destroy_mentor_should_destroy_the_groups
    group = groups(:mygroup)
    mentor = group.mentors.first
    assert_difference("Group.count", -1) do
      assert_difference("Connection::Membership.count", -2) do
        mentor.destroy
      end
    end
  end

  def test_destroy_group
    Group.destroy_all
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:f_mentor).max_connections_limit
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g1 = create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student), users(:f_mentor_student)])
    g2 = create_group(:mentors => [users(:f_mentor_student)], :students => [users(:f_student)])
    g3 = create_group(:mentors => [users(:f_mentor), users(:mentor_3)], :students => [users(:student_3), users(:student_4)])

    assert_difference "Connection::Membership.count", -3 do
      assert_difference "Group.count", -1 do
        assert_difference "User.count", -1 do
          users(:f_student).destroy
        end
      end
    end

    assert_nil Group.find_by(id: g2.id)
    assert Group.find_by(id: g1.id)
    assert Group.find_by(id: g3.id)

    assert_difference "Connection::Membership.count", -3 do
      assert_difference "Group.count", -1 do
        assert_difference "User.count", -1 do
          users(:f_mentor).destroy
        end
      end
    end

    assert_nil Group.find_by(id: g1.id)
    group =  Group.find_by(id: g3.id)
    program = group.program
    mentoring_model = program.default_mentoring_model
    MentoringModel::Importer.new(mentoring_model, fixture_file_upload(File.join('files', IMPORT_CSV_FILE_NAME), 'text/csv')).import
    Group::MentoringModelCloner.new(group, program, mentoring_model.reload).copy_mentoring_model_objects
    membership = g3.memberships.first
    user_tasks = group.reload.mentoring_model_tasks.where(connection_membership_id: membership.id)
    
    user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end

    #Creating RA for 'many' scenario
    assert_difference('RecentActivity.count') do
      assert_no_difference "MentoringModel::Task.count" do
        membership.leave_connection_callback = true    
        membership.destroy
        assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_MEMBER_LEAVING
      end  
    end 
    
    user_tasks.each do |task|
      assert task.reload && !task.connection_membership_id? && task.from_template? && task.unassigned_from_template?
    end
  end

  def test_track_state_changes
    Timecop.freeze do
      g1 = nil
      assert_difference "ConnectionMembershipStateChange.count", 3 do
        g1 = create_group(:mentors => [users(:mentor_4), users(:mentor_3)], :students => [users(:student_4)])
      end
      assert_not_equal g1.memberships.first.user.state, User::Status::SUSPENDED
      assert_difference "ConnectionMembershipStateChange.count", g1.memberships.first.user.connection_memberships.count do
        g1.memberships.first.user.update_attribute(:state, User::Status::SUSPENDED)
      end
      assert_difference "ConnectionMembershipStateChange.count", 1 do
        g1.mentor_memberships.create!(user_id: users(:mentor_2).id)
      end
      assert_nil ConnectionMembershipStateChange.last.info_hash[:connection_membership][:from_state]
      assert_equal Connection::Membership::Status::ACTIVE, ConnectionMembershipStateChange.last.info_hash[:connection_membership][:to_state]

      assert_difference "ConnectionMembershipStateChange.count", 1 do
        g1.mentor_memberships.first.destroy
      end
      assert_equal Connection::Membership::Status::ACTIVE, ConnectionMembershipStateChange.last.info_hash[:connection_membership][:from_state]
      assert_nil ConnectionMembershipStateChange.last.info_hash[:connection_membership][:to_state]
    end
  end

  def test_creating_membership_should_create_membership_state_change_and_user_state_change
    user = users(:student_5)
    user.connection_memberships.destroy_all
    membership = nil
    assert_difference 'ConnectionMembershipStateChange.count', 1 do
      assert_difference 'UserStateChange.count', 1 do
        membership = Connection::Membership.create!(
          :group => groups(:mygroup),
          :user => user,
          :status => Connection::Membership::Status::ACTIVE,
          :role_id => user.roles.find_by(name: RoleConstants::STUDENT_NAME).id
        )
      end
    end
    membership_role_id = membership.role_id
    assert_equal [], UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal [membership_role_id], UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    assert_nil ConnectionMembershipStateChange.last.info_hash[:connection_membership][:from_state]
    assert_equal Connection::Membership::Status::ACTIVE, ConnectionMembershipStateChange.last.info_hash[:connection_membership][:to_state]
    assert_equal membership_role_id, ConnectionMembershipStateChange.last.role_id
    assert_difference 'ConnectionMembershipStateChange.count', 1 do
      membership.destroy
    end

    assert_equal [membership_role_id], UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal [], UserStateChange.last.connection_membership_info_hash["role"]["to_role"]
    assert_equal Connection::Membership::Status::ACTIVE, ConnectionMembershipStateChange.last.info_hash[:connection_membership][:from_state]
    assert_nil ConnectionMembershipStateChange.last.info_hash[:connection_membership][:to_state]
    assert_equal membership_role_id, ConnectionMembershipStateChange.last.role_id
  end

  def test_member_indexing
    user = users(:student_5)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Group, [groups(:mygroup).id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:mkr_student).id, users(:f_mentor).id, user.id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [user.member_id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).twice.with(User, [user.id])
    Connection::Membership.create!(
      :group => groups(:mygroup),
      :user => user,
      :status => Connection::Membership::Status::ACTIVE,
      :role_id => user.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    )
  end

  def test_creating_membership_should_not_create_membership_state_change_and_user_state_change
    user = users(:student_5)
    user.connection_memberships.destroy_all
    membership = nil
    assert_no_difference 'ConnectionMembershipStateChange.count' do
      assert_no_difference 'UserStateChange.count' do
        membership = Connection::Membership.create!(
          :group => groups(:mygroup),
          :user => user,
          :status => Connection::Membership::Status::ACTIVE,
          :role_id => user.roles.find_by(name: RoleConstants::STUDENT_NAME).id,
          :created_for_sales_demo => true
        )
      end
    end
  end
end
