require_relative './../../../test_helper'

class HealthReport::ConnectivityTest < ActiveSupport::TestCase
  def test_compute_connectivity
    program = programs(:albers)
    role_map = role_map_for(program)
    program.groups.destroy_all
    program.mentor_requests.destroy_all
    program.mentor_requests.destroy_all
    connectivity = HealthReport::Connectivity.new(program, role_map)
    assert connectivity.mentor_request_wait_time.no_data?
    connectivity.compute
    assert_equal [0, 0, 0], connectivity.percent_metrics.values.map{|metric| metric.value}
    assert connectivity.mentor_request_wait_time.no_data?

    cur_time = Time.now
    wait_time_map = {}
    req1 = create_mentor_request(
      :student => users(:student_4), :created_at => cur_time - 1.day)
    wait_time_map[req1] = 1
    
    req2 = create_mentor_request(
      :student => users(:student_5),
      :created_at => cur_time - (HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD.days - 1.day))

    wait_time_map[req2] = HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD - 1
    req3 = create_mentor_request(
      :student => users(:student_6),
      :created_at => cur_time - (HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD.days + 2.days))

    wait_time_map[req3] = HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD.days + 2
    req4 = create_mentor_request(
      :student => users(:student_7),
      :created_at => cur_time - (HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD.days + 6.days))

    wait_time_map[req4] = HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD + 6
    req1.assign_mentor!(users(:mentor_4))
    req3.status = AbstractRequest::Status::REJECTED
    req3.response_text = 'Hello'
    req3.rejector = users(:f_admin)
    req3.save!

    MentorRequest.skip_timestamping do
      req3.update_attribute :updated_at, 1.day.ago
    end

    wait_time_map[req3] = HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD + 1
    users(:student_2).suspend_from_program!(users(:f_admin), 'Test')
    users(:f_mentor).update_attribute :max_connections_limit, 5
    assert_difference 'Group.count', 3 do
      @g1 = create_group(:mentor => users(:f_mentor), :students => [users(:f_student)])
      @g2 = create_group(:mentor => users(:mentor_1), :students => [users(:rahim)])
      @g3 = create_group(:mentor => users(:f_mentor), :students => [users(:student_1)])
    end
    
    connectivity = HealthReport::Connectivity.new(program, role_map)
    connectivity.compute
    assert_equal [3.0 / program.mentor_users.active.count, 4.0 / program.student_users.active.count, 0], connectivity.percent_metrics.values.map{|metric| metric.value}
    assert_equal wait_time_map.values.average, connectivity.mentor_request_wait_time.effective_value
    
    assert_difference 'Group.count', 1 do
      @g1.students << users(:student_3)
      @g4 = create_group(:mentor => users(:robert), :students => [users(:rahim)])
      @g3.terminate!(users(:f_admin), 'Test', @g3.program.permitted_closure_reasons.first.id)
    end
    
    req2.assign_mentor!(users(:mentor_5))
    MentorRequest.skip_timestamping do
      req2.update_attribute :updated_at, 3.days.ago
    end

    wait_time_map[req2] = HealthReport::Connectivity::MENTOR_REQUEST_WAIT_TIME_THRESHOLD - 4
    connectivity = HealthReport::Connectivity.new(program, role_map)
    connectivity.compute
    assert_equal [5.0 / program.mentor_users.active.count, 5.0 / program.student_users.active.count, 0], connectivity.percent_metrics.values.map{|metric| metric.value}
    assert_equal wait_time_map.values.average, connectivity.mentor_request_wait_time.effective_value
  end

  def test_compute_connectivity_for_no_mentor_requests_program
    program = programs(:no_mentor_request_program)
    role_map = role_map_for(program)
    connectivity = HealthReport::Connectivity.new(program, role_map)
    assert connectivity.mentor_request_wait_time.no_data?
    connectivity.compute
    assert connectivity.mentor_request_wait_time.no_data?
  end

  private
  
  def role_map_for(program)
    role_map = {}
    program.roles_without_admin_role.each{|role| role_map[role.name] = role.id }
    role_map
  end
end
