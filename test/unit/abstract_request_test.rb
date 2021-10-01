require_relative './../test_helper.rb'

class AbstractRequestTest < ActiveSupport::TestCase
  def test_belongs_to_program
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    assert_equal programs(:albers), ar.program
  end

  def test_presence_of_program
    ar = AbstractRequest.create(type: AbstractRequest.name, status: AbstractRequest::Status::NOT_ANSWERED)
    assert_equal ["can't be blank"], ar.errors[:program]
  end

  def test_validations
    ar1 = AbstractRequest.create(type: AbstractRequest.name, program: programs(:albers), status: nil, allowed_request_type_change: nil)
    assert_equal ["can't be blank", "is not included in the list"], ar1.errors[:status]
    assert_empty ar1.errors[:allowed_request_type_change]

    ar2 = AbstractRequest.create(type: AbstractRequest.name, program: programs(:albers), status: 543, allowed_request_type_change: 583)
    assert_equal ["is not included in the list"], ar2.errors[:status]
    assert_equal ["is not included in the list"], ar2.errors[:allowed_request_type_change]
  end

  def test_active_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    assert AbstractRequest.active.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false AbstractRequest.active.pluck(:id).include?(ar.id)
  end

  def test_inactive_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    assert_false AbstractRequest.inactive.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert AbstractRequest.inactive.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::REJECTED)
    assert AbstractRequest.inactive.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::WITHDRAWN)
    assert AbstractRequest.inactive.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::CLOSED)
    assert AbstractRequest.inactive.pluck(:id).include?(ar.id)
  end

  def test_for_program_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    assert AbstractRequest.for_program(programs(:albers)).pluck(:id).include?(ar.id)
    assert_false AbstractRequest.for_program(programs(:nwen)).pluck(:id).include?(ar.id)
  end

  def test_from_student_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED, sender_id: users(:f_admin).id)
    assert AbstractRequest.from_student(users(:f_admin)).pluck(:id).include?(ar.id)
    assert_false AbstractRequest.from_student(users(:f_mentor)).pluck(:id).include?(ar.id)
  end

  def test_to_mentor_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED, receiver_id: users(:f_admin).id)
    assert AbstractRequest.to_mentor(users(:f_admin)).pluck(:id).include?(ar.id)
    assert_false AbstractRequest.to_mentor(users(:f_mentor)).pluck(:id).include?(ar.id)
  end

  def test_with_role_scope
    mentor_role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    mentee_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED, sender_role_id: mentor_role.id)
    assert AbstractRequest.with_role(mentor_role).pluck(:id).include?(ar.id)
    assert_false AbstractRequest.with_role(mentee_role).pluck(:id).include?(ar.id)
  end

  def test_accepted_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::ACCEPTED)
    assert AbstractRequest.accepted.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::NOT_ANSWERED)
    assert_false AbstractRequest.accepted.pluck(:id).include?(ar.id)
  end

  def test_rejected_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::REJECTED)
    assert AbstractRequest.rejected.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false AbstractRequest.rejected.pluck(:id).include?(ar.id)
  end

  def test_withdrawn_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::WITHDRAWN)
    assert AbstractRequest.withdrawn.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false AbstractRequest.withdrawn.pluck(:id).include?(ar.id)
  end

  def test_closed_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::CLOSED)
    assert AbstractRequest.closed.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false AbstractRequest.closed.pluck(:id).include?(ar.id)
  end

  def test_answered_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::ACCEPTED)
    assert AbstractRequest.answered.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::REJECTED)
    assert AbstractRequest.answered.pluck(:id).include?(ar.id)

    ar.update_attributes(status: AbstractRequest::Status::NOT_ANSWERED)
    assert_false AbstractRequest.answered.pluck(:id).include?(ar.id)
  end

  def test_with_status_in
    ar_pen = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    ar_rej = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::REJECTED)
    ar_acc = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::ACCEPTED)
    ar_clo = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::CLOSED)
    ar_wit = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::WITHDRAWN)

    pen = AbstractRequest.with_status_in([AbstractRequest::Status::NOT_ANSWERED]).pluck(:id)
    assert pen.include?(ar_pen.id)
    assert_false pen.include?(ar_rej.id)
    assert_false pen.include?(ar_acc.id)
    assert_false pen.include?(ar_clo.id)
    assert_false pen.include?(ar_wit.id)

    other = AbstractRequest.with_status_in([AbstractRequest::Status::REJECTED, AbstractRequest::Status::CLOSED, AbstractRequest::Status::WITHDRAWN]).pluck(:id)

    assert other.include?(ar_rej.id)
    assert other.include?(ar_clo.id)
    assert other.include?(ar_wit.id)
    assert_false other.include?(ar_pen.id)
    assert_false other.include?(ar_acc.id)
  end

  def test_created_in_date_range_scope
    t = Time.now
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    date_range = t..Time.now
    assert AbstractRequest.created_in_date_range(date_range).pluck(:id).include?(ar.id)
  end

  def test_updated_in_date_range_scope
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)

    t = Time.now
    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    date_range = t..Time.now
    assert AbstractRequest.updated_in_date_range(date_range).pluck(:id).include?(ar.id)
  end

  def test_accepted_in
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)    
    t = Time.now
    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED, accepted_at: Time.now)
    assert AbstractRequest.accepted_in(t, Time.now).pluck(:id).include?(ar.id)
  end

  def test_active
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    assert ar.active?

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false ar.active?
  end

  def test_accepted
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::ACCEPTED)
    assert ar.accepted?

    ar.update_attributes(status: AbstractRequest::Status::NOT_ANSWERED)
    assert_false ar.accepted?
  end

  def test_rejected
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::REJECTED)
    assert ar.rejected?

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false ar.rejected?
  end

  def test_withdrawn
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::WITHDRAWN)
    assert ar.withdrawn?

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false ar.withdrawn?
  end

  def test_closed
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::CLOSED)
    assert ar.closed?

    ar.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_false ar.closed?
  end

  def test_allow_request_type_change_from_mentor_to_meeting
    ar = AbstractRequest.new(type: AbstractRequest.name, program: programs(:albers), allowed_request_type_change: AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST, status: AbstractRequest::Status::NOT_ANSWERED)
    assert ar.allow_request_type_change_from_mentor_to_meeting?

    ar.allowed_request_type_change =nil
    assert_false ar.allow_request_type_change_from_mentor_to_meeting?
  end

  def test_close
    ar = AbstractRequest.create!(type: AbstractRequest.name, program: programs(:albers), status: AbstractRequest::Status::NOT_ANSWERED)
    ar.close!('some text')

    assert ar.closed?
    assert_equal 'some text', ar.response_text

    ar.close!('some other text')
    assert_equal 'some text', ar.reload.response_text

    ar.update_attributes(status: AbstractRequest::Status::NOT_ANSWERED)
    assert_false ar.closed?
    ar.close!('one more time')
    assert_equal 'one more time', ar.reload.response_text
  end

  def test_pending_notifications_should_dependent_destroy_on_abstract_request_deletion
    abstract_request = AbstractRequest.create!(type: AbstractRequest.name, :program => programs(:albers), :status => AbstractRequest::Status::ACCEPTED)
    user = users(:f_mentor)
    #Testing has_many association
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED, RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED]
    assert_difference "PendingNotification.count", 2 do
      action_types.each do |action_type|
        pending_notifications << abstract_request.pending_notifications.create!(
                  ref_obj_creator: user,
                  ref_obj: abstract_request,
                  program: abstract_request.program,
                  action_type: action_type)
      end
    end
    #Testing dependent destroy
    assert_equal pending_notifications, abstract_request.pending_notifications
    assert_difference 'AbstractRequest.count', -1 do
      assert_difference 'PendingNotification.count', -2 do
        abstract_request.destroy
      end
    end
  end
end
