require_relative './../../../test_helper.rb'

class Api::V2::UsersPresenterTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    # get users
    @admin = users(:f_admin)
    @mentor = users(:robert)
    @users = [@admin, @mentor]
    # add role to admin
    @admin.roles << @program.get_role(RoleConstants::STUDENT_NAME)
    @admin.save
    # build presenter
    @presenter = Api::V2::UsersPresenter.new(@program, @program.organization)
    Matching.expects(:remove_user).at_least(0).returns(nil)
  end

  # list
  def test_list_should_success_without_params
    result = @presenter.list

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 45, result[:data].size

    # make sure we have all users in output
    user_hash = result[:data][0]
    user_asserts @users[0], user_hash
    user_hash = result[:data][7]
    user_asserts @users[1], user_hash

    assert_equal ["admin","mentee"], result[:data][0][:roles]
    assert_equal ["mentor"], result[:data][7][:roles]
  end

  def test_list_should_success_with_email_given
    result = @presenter.list(email: "userrobert@example.com")

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size

    user_hash = result[:data][0]
    user_asserts @users[1], user_hash
    assert_equal ["mentor"], result[:data][0][:roles]
  end

  def test_list_should_success_with_roles_given
    result = @presenter.list(roles: "mentee")

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 22, result[:data].size

    user_hash = result[:data].find{|user| user[:email] == @users[0].member.email}
    user_asserts @users[0], user_hash
    assert_equal ["admin","mentee"], user_hash[:roles]
  end

  def test_list_should_success_with_status
    result = @presenter.list(status: User::Status::ACTIVE)
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    active_user_size = programs(:albers).users.where(state: User::Status::ACTIVE).count
    assert_equal active_user_size, result[:data].size
    user_hash = result[:data].find{|user| user[:email] == @mentor.member.email}
    user_asserts @mentor, user_hash

    @mentor.state = User::Status::PENDING
    @mentor.save!

    result = @presenter.list(status: User::Status::ACTIVE)
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal active_user_size - 1, result[:data].size
    user_hash = result[:data].find{|user| user[:email] == @mentor.member.email}
    assert_nil user_hash
  end

  def test_list_should_failed_with_invalid_status
    result = @presenter.list(status: 12)
    assert_false result[:success]
    assert_equal 1, result[:errors].size
    assert_equal "Incorrect Status", result[:errors][0]
  end

  def test_list_should_fail_with_invalid_roles
    result = @presenter.list(roles: "admin,root")

    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal ["Incorrect Roles"], result[:errors]
  end

  def test_list_should_success_no_profile_with_profile_given
    result = @presenter.list(profile: "1", roles: "mentor")

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 23, result[:data].size

    user_hash = result[:data][3]
    user_asserts @mentor, user_hash, false
    profile_hash = user_hash[:profile]
    assert_nil profile_hash
  end

  # create
  def test_create_should_success_with_new_member
    custom_auth = @program.organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    params = {
      email:      "new_user@example.com",
      first_name: "New",
      last_name:  "User",
      roles:      "mentee",
      login_name: "new_user"
    }
    result = nil
    assert_no_emails do
      assert_difference "@program.organization.members.count" do
        assert_difference "@program.users.count" do
          result = @presenter.create(params)
        end
      end
    end
    @program.reload
    member = Member.last
    login_identifiers = member.login_identifiers
    user = @program.users.last
    assert_instance_of Hash, result
    assert result[:success]
    expect = { uuid: member.id }
    assert_equal expect, result[:data]
    assert_equal "New", member.first_name
    assert_equal "User", member.last_name
    assert_equal "new_user@example.com", member.email
    assert_equal [custom_auth], login_identifiers.map(&:auth_config)
    assert_equal ["new_user"], login_identifiers.map(&:identifier)
    assert_equal [RoleConstants::STUDENT_NAME], user.role_names
  end

  def test_create_should_success_with_send_invite
    params = {
      email:      "new_user@example.com",
      first_name: "New",
      last_name:  "User",
      roles:      "mentee",
      acting_user: @admin,
      send_invite: "1"
    }
    result = nil
    assert_emails 1 do
      assert_difference "@program.organization.members.count", 1 do
        assert_difference "@program.users.count", 1 do
          result = @presenter.create(params)
        end
      end
    end
    @program.reload
    member = Member.last
    user = @program.users.last
    assert_instance_of Hash, result
    assert result[:success]
    expect = { uuid: member.id }
    assert_equal expect, result[:data]
    assert_equal "New", member.first_name
    assert_equal "User", member.last_name
    assert_equal "new_user@example.com", member.email
    assert_equal [RoleConstants::STUDENT_NAME], user.role_names
  end

  def test_create_should_success_with_existing_member
    member = members(:f_mentor)
    user = users(:f_mentor)
    user.destroy
    @program.reload
    params = {
      uuid: member.id,
      email: member.email,
      roles: "mentor"
    }
    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_difference "@program.users.count", 1 do
        result = @presenter.create(params)
      end
    end

    @program.reload
    user = @program.users.last
    assert result[:success]
    assert result[:success]
    expect = { uuid: member.id }
    assert_equal expect, result[:data]
    assert_equal member, user.member
    assert_equal user.roles.collect(&:name), ["mentor"]
  end

  def test_create_should_success_with_existing_member_only_email
    member = members(:f_mentor)
    user = users(:f_mentor)
    user.destroy
    @program.reload
    params = {
      email: member.email,
      roles: "mentor"
    }
    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_difference "@program.users.count", 1 do
        result = @presenter.create(params)
      end
    end

    @program.reload
    user = @program.users.last
    assert result[:success]
    assert result[:success]
    expect = { uuid: member.id }
    assert_equal expect, result[:data]
    assert_equal member, user.member
    assert_equal user.roles.collect(&:name), ["mentor"]
  end

  def test_create_should_success_with_existing_user_only_email
    member = members(:f_mentor)
    @program.reload
    params = {
      email: member.email,
      roles: "mentor"
    }
    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_difference "@program.users.count", 0 do
        result = @presenter.create(params)
      end
    end

    @program.reload
    user = users(:f_mentor)
    assert result[:success]
    assert result[:success]
    expect = { uuid: member.id }
    assert_equal expect, result[:data]
    assert_equal member, user.member
    assert_equal user.roles.collect(&:name), ["mentor"]
  end

  def test_create_for_exisiting_user_without_email
    member = members(:rahim)
    params = {
      uuid:       member.id,
      email:      "",
      first_name: "New",
      last_name:  "User",
      roles:      "mentee",
    }

    user = member.user_in_program(@program)

    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_no_difference "@program.users.count" do
        result = @presenter.create(params)
      end
    end

    assert_instance_of Hash, result
    assert result[:success]
    expect = { uuid: member.id }
    assert_equal expect, result[:data]
    assert_equal member, user.member
    assert_equal user.roles.collect(&:name), [RoleConstants::STUDENT_NAME]
  end

  def test_create_should_fail_with_incorrect_roles
    params = {
      email:      "new_user@example.com",
      first_name: "New",
      last_name:  "User",
      roles:      "mentee, bord_of_director",
    }
    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_no_difference "@program.users.count" do
        result = @presenter.create(params)
      end
    end

    assert_false result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal ["Incorrect Roles"], result[:errors]
  end

  def test_create_should_fail_if_member_is_invalid
    params = {
      uuid:       Member.count+5,
      email:      "new_user@example.com",
      first_name: "New",
      last_name:  "User",
      roles:      "mentee",
    }
    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_no_difference "@program.users.count" do
        result = @presenter.create(params)
      end
    end
    user = @program.users.last

    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_match "user with uuid '#{Member.count+5}' not found", result[:errors][0]
  end

  def test_create_should_fail_if_roles_are_invalid
    params = {
      email:      "new_user@example.com",
      first_name: "New",
      last_name:  "User",
      roles:      "root,admin",
    }
    result = nil
    assert_no_difference "@program.users.count" do
      result = @presenter.create(params)
    end
    user = @program.users.last

    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "Incorrect Roles", result[:errors][0]
  end

  def test_destroy_invalid_uuid
    uuid = Member.count + 5
    result = @presenter.destroy(uuid)

    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "user with uuid '#{uuid}' not found", result[:errors][0]
  end

  def test_destroy_cannot_remove
    result = nil

    User.any_instance.expects(:can_be_removed_or_suspended?).returns(false)
    assert_no_difference "User.count" do
      result = @presenter.destroy(@mentor.id)
    end
    assert_false result[:success]
    assert_equal ["This user cannot be removed"], result[:errors]
  end

  def test_destroy
    uuid = @mentor.id

    result = nil
    assert_no_difference "@program.organization.members.count" do
      assert_difference "@program.users.count", -1 do
        result = @presenter.destroy(uuid)
      end
    end

    assert_instance_of Hash, result
    assert result[:success]
    expect = { uuid: uuid }
    assert_equal expect, result[:data]
  end

  def test_update_user_status_with_errors
    mentor = members(:f_mentor)

    result = @presenter.update_status({}, @admin.member)
    assert_false result[:success]
    assert_equal ["uuid not passed", "status not passed"], result[:errors]

    result = @presenter.update_status( { uuid: 'some_random_id' }, @admin.member)
    assert_false result[:success]
    assert_equal ["status not passed", "member with uuid 'some_random_id' not found"], result[:errors]

    invalid_status_params = []
    invalid_status_params << { uuid: mentor.id, status: -1 }
    (User::Status.all - User::Status.allowed_in_api).each do |status|
      invalid_status_params << {  uuid: mentor.id, status: UsersHelper::STATE_TO_INTEGER_MAP[status] }
    end
    invalid_status_params.each do |params|
      result = @presenter.update_status(params, @admin.member)
      assert_false result[:success]
      assert_equal ["invalid update status passed"], result[:errors]
    end

    User.any_instance.stubs(:state_transition_allowed_in_api?).returns(false)
    params = { uuid: mentor.id, status: User::Status::SUSPENDED }
    result = @presenter.update_status(params, @admin.member)
    assert_false result[:success]
    assert_equal ["This state transition is not allowed"], result[:errors]

    params = { uuid: mentor.id, status: UsersHelper::STATE_TO_INTEGER_MAP[User::Status::ACTIVE] }
    users(:f_mentor).destroy
    result = @presenter.update_status(params, @admin.member)
    assert_false result[:success]
    assert_equal ["member with uuid '#{mentor.id}' is not part of the program"], result[:errors]
  end

  def test_update_user_status_success
    current_program = programs(:albers)
    user = users(:f_mentor)
    mentor = members(:f_mentor)
    admin = members(:f_admin)
    states_to_be_checked = {}
    User::Status.all.each do |status|
      states_to_be_checked[status] = User::Status.allowed_in_api
    end

    states_to_be_checked.each do |from_state, to_states|
      to_states.each do |to_state|
        user.state = from_state
        user.track_reactivation_state = User::Status::ACTIVE
        user.save!
        to_status = UsersHelper::STATE_TO_INTEGER_MAP[to_state]
        params = { uuid: mentor.id, status: to_status }
        result = @presenter.update_status(params, admin)
        if from_state == User::Status::SUSPENDED && to_state == User::Status::ACTIVE
          email = ActionMailer::Base.deliveries.last
          assert_equal [user.email], email.to
          assert_equal "Your account is now reactivated!", email.subject
        end
        assert result[:success]
        assert_equal to_state, user.reload.state
      end
    end

    # Checking for state chnage reason
    from_state = User::Status::PENDING
    to_state = User::Status::SUSPENDED
    user.state = from_state
    user.save!
    to_status_i = UsersHelper::STATE_TO_INTEGER_MAP[to_state]
    params = { uuid: mentor.id, status: to_status_i }
    result = @presenter.update_status(params, admin)
    user.reload
    assert result[:success]
    assert_equal User::Status::SUSPENDED, user.state
  end

  protected

  def user_asserts(user, user_hash, with_profile = false)
    assert_instance_of Hash, user_hash
    expected_keys  = [:first_name, :last_name, :email, :status, :uuid, :roles]
    expected_keys += [:profile] if with_profile

    expected_keys.each do |expected_key|
      assert user_hash.has_key?(expected_key), "user hash should contain #{expected_key.inspect} key"
    end

    assert_equal user.first_name, user_hash[:first_name]
    assert_equal user.last_name, user_hash[:last_name]
    assert_equal user.email, user_hash[:email]
    assert_equal UsersHelper::STATE_TO_INTEGER_MAP[user.state], user_hash[:status]
    assert_equal user.member.id, user_hash[:uuid]
  end
end