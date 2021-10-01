require_relative './../../../test_helper.rb'

class Api::V2::ConnectionsPresenterTest < ActiveSupport::TestCase
  def setup
    super
    @groups = [groups(:mygroup), groups(:group_2)]
    @program = programs(:albers)
    @presenter = Api::V2::ConnectionsPresenter.new(@program)
  end

  # list
  def test_list_should_success_with_draft_state
    # set DRAFT state
    @groups[1].update_attribute(:status, Group::Status::DRAFTED)

    result = @presenter.list(state: 0)

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 4, result[:data].size

    group = @groups[1]
    group_hash = result[:data][0]

    group_asserts group, group_hash
  end

  def test_list_should_success_with_active_state
    result = @presenter.list(state: 1)

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 5, result[:data].size

    # make sure we received all active groups
    @groups.each_with_index do |group, group_index|
      group_hash = result[:data][group_index]
      group_asserts group, group_hash
    end
  end

  def test_list_should_success_with_terminated_state
    # set CLOSED state
    @groups[1].terminate!(users(:f_admin), "just for test", @groups[1].program.permitted_closure_reasons.first.id)

    result = @presenter.list(state: 2)

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 2, result[:data].size

    group = @groups[1]
    group_hash = result[:data][0]

    group_asserts group, group_hash
  end

  def test_list_should_success_with_inactive_state
    # set INACTIVE state
    @groups[1].update_attribute(:status, Group::Status::INACTIVE)

    result = @presenter.list(state: 3)

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 2, result[:data].size

    group = @groups[1]
    group_hash = result[:data][0]

    group_asserts group, group_hash
  end

  def test_list_should_success_with_email
    result = @presenter.list(email: "robert@example.com")

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size

    group = @groups[0]
    group_hash = result[:data][0]

    group_asserts group, group_hash
  end

  def test_list_should_success_without_params
    result = @presenter.list

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 10, result[:data].size

    # make sure we have all groups in output
    @groups.each_with_index do |group, group_index|
      group_hash = result[:data][group_index]
      group_asserts group, group_hash
    end
  end

  # find
  def test_find_should_success_if_profile_param_set
    group = @groups[0]
    result = @presenter.find(group.id, profile: 1)
    profiles = group.answers

    assert_instance_of Hash, result
    assert result[:success]
    group_asserts group, result[:data], true

    profiles_data = result[:data][:profiles]
    assert_instance_of Array, profiles_data
    assert_equal 3, profiles_data.size
    profiles.each_with_index do |p, index|
      assert_equal p.question.id, profiles_data[index][:id]
      assert_equal p.selected_choices_to_str, profiles_data[index][:answer]
    end
  end

  # ACTIVITIES LISTING DISABLED FOR NOW
  # def test_find_should_success_if_activity_report_param_set
  #   group = @groups[0]
  #   # create activity
  #   activity = RecentActivity.create!(
  #     programs:    [@program],
  #     action_type: RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION,
  #     target:      RecentActivityConstants::Target::ALL,
  #     ref_obj:     group,
  #     member:      group.members.first.member,
  #     message:     "some message"
  #   )
  #   activities = [activity]
  #   result = @presenter.find(group.id, activity_report: 1)
  #   group.reload # to be sure we have actual data
  #
  #   assert_instance_of Hash, result
  #   assert result[:success]
  #   group_asserts group, result[:data], true
  #
  #   activities_data = result[:data][:activities]
  #   assert_instance_of Array, activities_data
  #   assert_equal 1, activities_data.size
  #   assert_equal RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION, activities_data[0][:action_type]
  #   assert_equal RecentActivityConstants::Target::ALL, activities_data[0][:target]
  #   assert_equal "some message", activities_data[0][:message]
  # end

  def test_find_should_success_without_params
    result = @presenter.find(2)

    assert_instance_of Hash, result
    assert result[:success]
    group_asserts @groups[1], result[:data], true
  end

  def test_find_should_be_not_success_if_group_does_not_exists
    result = @presenter.find(7)
    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "connection with id=7 was not found", result[:errors][0]
  end

  # create
  def test_create_should_success_with_emails_only
    mentor_emails = "userrobert@example.com"
    mentee_emails = "mkr@example.com"

    result = nil
    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
      status:       Api::V2::ConnectionsPresenter::Status::ACTIVE,
      acting_user:  users(:f_admin),
    }
    assert_emails 2 do
      assert_difference "@program.groups.count", 1 do
        result = @presenter.create(params)
      end
    end
    group = @program.groups.last
    assert_instance_of Hash, result
    # should be active by default
    assert_equal Group::Status::ACTIVE, group.status
    assert_equal 1, group.mentors.count
    assert_equal 1, group.students.count
    expect = { id: group.id, mentor_ids: get_member_ids_from_emails(mentor_emails, @program), student_ids: get_member_ids_from_emails(mentee_emails, @program) }
    assert_equal expect, result[:data]
    assert result[:success]
  end

  def test_create_should_succeed_with_mentoring_template_id
    mentor_emails = "userrobert@example.com"
    mentee_emails = "mkr@example.com"

    result = nil
    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
      template_id: "1",
      status:       Api::V2::ConnectionsPresenter::Status::ACTIVE,
      acting_user:  users(:f_admin),
    }
    assert_emails 2 do
      assert_difference "@program.groups.count", 1 do
        result = @presenter.create(params)
      end
    end
    group = @program.groups.last
    assert_instance_of Hash, result
    # should be active by default
    assert_equal Group::Status::ACTIVE, group.status
    assert_equal 1, group.mentors.count
    assert_equal 1, group.students.count
    assert_equal 1, group.mentoring_model_id
    expect = { id: group.id, mentor_ids: get_member_ids_from_emails(mentor_emails, @program), student_ids: get_member_ids_from_emails(mentee_emails, @program) }
    assert_equal expect, result[:data]
    assert result[:success]
  end

  def test_create_should_fail_with_unavailable_mentoring_template_id
    mentor_emails = "userrobert@example.com"
    mentee_emails = "mkr@example.com"

    result = nil
    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
      template_id: "1000",
      status:       Api::V2::ConnectionsPresenter::Status::ACTIVE,
      acting_user:  users(:f_admin),
    }
    assert_no_difference "@program.groups.count" do
      result = @presenter.create(params)
    end
  end

  def test_create_should_success_with_valid_params
    # make it possible to add >1 student
    @program.update_attribute(:allow_one_to_many_mentoring, true)

    mentor_emails = "userrobert@example.com"
    mentee_emails = "mkr@example.com,student_0@example.com"
    result = nil
    creator = users(:f_admin)
    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
      name:         "New group name",
      status:       Api::V2::ConnectionsPresenter::Status::DRAFTED,
      note:         "Test group note",
      acting_user:  creator,
    }
    assert_difference "@program.groups.count", 1 do
      result = @presenter.create(params)
    end
    group = @program.groups.last

    assert_instance_of Hash, result
    assert_equal creator, group.created_by
    assert_equal "New group name", group.name
    assert_equal "Test group note", group.notes
    assert_equal Group::Status::DRAFTED, group.status
    assert_equal creator, group.created_by
    assert_equal 1, group.mentors.count
    assert_equal 2, group.students.count
    expect = { id: group.id, mentor_ids: get_member_ids_from_emails(mentor_emails, @program), student_ids: get_member_ids_from_emails(mentee_emails, @program) }
    assert_equal expect, result[:data]
    assert result[:success]
  end

  def test_create_should_fail_if_mentor_not_found
    mentor_emails = "not_found@example.com"
    mentee_emails = "mkr@example.com"

    result = nil
    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
    }
    assert_no_difference "@program.groups.count" do
      result = @presenter.create(params)
    end
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "user with email 'not_found@example.com' not found", result[:errors][0]
  end

  def test_create_should_fail_if_mentor_not_given
    mentor_emails = ""
    mentee_emails = "mkr@example.com"

    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
    }
    result = nil
    assert_no_difference "@program.groups.count" do
      result = @presenter.create(params)
    end
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "Mentors can't be blank", result[:errors][0]
  end

  def test_create_should_not_success_if_expiry_date_is_invalid
    mentor_emails = "userrobert@example.com"
    mentee_emails = "mkr@example.com,student_0@example.com"

    result = nil
    params = {
      mentor_email: mentor_emails,
      mentee_email: mentee_emails,
      expiry_date:  "21200132",
    }
    assert_no_difference "@program.groups.count" do
      result = @presenter.create(params)
    end
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal ":expiry_date has invalid format, please use YYYYMMDD", result[:errors][0]
  end

  # update
  def test_update_should_fail_with_invalid_profile_params
    group = @groups[0]
    profile = group.answers[1]
    params = {
      profile: {
        profile.common_question_id => "new answer text"
      }
    }
    result = @presenter.update(group.id, params)
    profile.reload # make sure we have actual data
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "opt_1", profile.selected_choices_to_str
  end

  def test_update_should_success_if_answer_doesnt_exist_yet
    group = @groups[0]
    profile = group.answers[1]
    question_id = profile.common_question_id
    # remove answer
    profile.destroy
    params = {
      profile: {
        question_id => "opt_3"
      }
    }
    result = @presenter.update(group.id, params)
    group_asserts group, result[:data], true
    profile = group.answer_for(@program.connection_questions.find(question_id))
    assert_not_nil profile
    assert_equal "opt_3", profile.selected_choices_to_str
  end


  def test_update_should_success_with_valid_profile_params
    group = @groups[0]
    profile = group.answers[1]
    params = {
      profile: {
        profile.common_question_id => "opt_3"
      }
    }
    result = @presenter.update(group.id, params)
    profile.reload # make sure we have actual data
    group_asserts group, result[:data], true
    assert_equal "opt_3", profile.selected_choices_to_str
  end

  def test_update_should_success_with_valid_params
    next_year = Date.today.year + 1
    params = {
      mentee_email: "student_0@example.com",
      name: "New group name",
      note: "Some description",
      expiry_date: "#{next_year}0101",
    }
    group = @groups[0]
    result = @presenter.update(group.id, params)
    group.reload # to be sure we have actual data
    group_asserts group, result[:data], true
    assert group.students.map(&:email).include?("student_0@example.com")
    # assert_equal 2, group.students.count
    assert_equal "New group name", group.name
    assert_equal "Some description", group.notes
    assert_equal DateTime.parse("#{next_year}0101").end_of_day.change(usec: 0), group.expiry_time
  end

  def test_update_should_change_status_if_terminated
    group = @groups[0]
    updater = users(:f_admin)
    params = {
      acting_user: updater,
      status: Api::V2::ConnectionsPresenter::Status::CLOSED,
      termination_reason: "Just a test",
    }
    current_time = Time.now
    result = Timecop.freeze(current_time) do
      @presenter.update(group.id, params)
    end
    group.reload # to be sure we have actual data
    group_asserts group, result[:data], true
    assert group.closed?
    assert_equal "Just a test", group.termination_reason
    assert_equal updater, group.closed_by
    assert_equal current_time.to_i, group.closed_at.to_i
    assert_equal Group::TerminationMode::ADMIN, group.termination_mode
  end

  def test_update_should_fail_if_termination_reason_is_blank
    group = @groups[0]
    updater = users(:f_admin)
    params = {
      acting_user: updater,
      status: Api::V2::ConnectionsPresenter::Status::CLOSED,
      termination_reason: "",
    }
    result = @presenter.update(group.id, params)
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "termination_reason can't be blank", result[:errors][0]

    assert !group.reload.closed?
  end

  def test_update_should_fail_if_termination_reason_is_missing
    group = @groups[0]
    updater = users(:f_admin)
    params = {
      acting_user: updater,
      status: Api::V2::ConnectionsPresenter::Status::CLOSED,
    }
    result = @presenter.update(group.id, params)
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "termination_reason can't be blank", result[:errors][0]

    assert !group.reload.closed?
  end

  def test_update_should_change_status_if_reopened
    group = @groups[0]
    updater = users(:f_admin)
    group.terminate!(updater, "To be continued...", group.program.permitted_closure_reasons.first.id)
    params = {
      acting_user: updater,
      status: Api::V2::ConnectionsPresenter::Status::ACTIVE,
    }
    result = nil
    assert_emails 2 do
      result = @presenter.update(group.id, params)
    end
    group.reload # to be sure we have actual data
    group_asserts group, result[:data], true
    assert group.active?
  end

  def test_update_should_not_success_if_expiry_date_is_invalid
    group = @groups[0]
    result = @presenter.update(group.id, expiry_date: "21200132")
    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal ":expiry_date has invalid format, please use YYYYMMDD", result[:errors][0]
  end

  def test_update_should_be_error_if_group_does_not_exists
    result = @presenter.update(7, {})
    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "connection with id=7 was not found", result[:errors][0]
  end

  # destroy
  def test_destroy_should_success
    group = @groups[0]
    result = nil
    assert_difference "@program.reload.groups.count", -1 do
      result = @presenter.destroy(group.id)
    end
    assert_instance_of Hash, result
    expect = { id: group.id }
    assert_equal expect, result[:data]
    assert result[:success]
  end

  def test_destroy_should_return_error_if_group_does_not_exists
    result = @presenter.destroy("invalid")
    assert_instance_of Hash, result
    assert !result[:success]
    assert_instance_of Array, result[:errors]
    assert_equal 1, result[:errors].size
    assert_equal "connection with id=invalid was not found", result[:errors][0]
  end

protected
  def group_asserts(group, group_hash, detailed = false)
    assert_instance_of Hash, group_hash

    expected_keys  = [:id, :name, :mentors, :mentees]
    expected_keys += [:state, :closed_on, :notes, :last_activity_on] if detailed
    expected_keys.each do |expected_key|
      assert group_hash.has_key?(expected_key), "group hash should contain #{expected_key.inspect} key"
    end

    assert_equal group.id, group_hash[:id]
    assert_equal group.name, group_hash[:name]
    if detailed
      assert group_hash.has_key?(:closed_on)
      assert group_hash.has_key?(:state)
      assert_dynamic_expected_nil_or_equal group.notes, group_hash[:notes]
      assert_equal group.last_activity_at.to_date, Date.parse(group_hash[:last_activity_on])
    end

    assert_instance_of Array, group_hash[:mentors]
    assert_equal 1, group_hash[:mentors].size
    group.mentors.each_with_index do |mentor, mentor_index|
      mentor_hash = group_hash[:mentors][mentor_index]
      assert_equal mentor.member_id, mentor_hash[:id]
      assert_equal mentor.name, mentor_hash[:name]
      assert_equal mentor.created_at.to_date, Date.parse(mentor_hash[:connected_at])
    end

    assert_instance_of Array, group_hash[:mentees]
    assert_equal 1, group_hash[:mentees].size
    group.students.each_with_index do |mentee, mentee_index|
      mentee_hash = group_hash[:mentees][mentee_index]
      assert_equal mentee.member_id, mentee_hash[:id]
      assert_equal mentee.name, mentee_hash[:name]
      assert_equal mentee.created_at.to_date, Date.parse(mentee_hash[:connected_at])
    end
  end

  def get_member_ids_from_emails(emails, program)
    member_ids = []
    emails.split(",").each do |email|
      member_ids << program.organization.members.find_by(email: email).id
    end
    member_ids
  end
end
