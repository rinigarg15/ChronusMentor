module HealthReport
  class Connectivity < CumulativeReport
    DEFAULT_CONNECTIVITY_THRESHOLD = 0.6
    CONNECTIVITY_THRESHOLD = {
      RoleConstants::MENTOR_NAME => 0.6,
      RoleConstants::STUDENT_NAME => 0.7
    }

    MENTOR_REQUEST_WAIT_TIME_THRESHOLD  = 5
    MENTOR_REQUEST_WAIT_TIME_MINIMUM    = 0
    MENTOR_REQUEST_WAIT_TIME_MAXIMUM    = 10

    attr_accessor :program, :role_map, :percent_metrics,
                  :mentor_request_wait_time

    cumulative_metric :percent_metrics, :mentor_request_wait_time

    def initialize(program, role_map)
      self.program = program
      self.role_map = role_map
      self.percent_metrics = {}
      self.role_map.keys.each do |role_name|
        self.percent_metrics[role_name] = PercentMetric.new(CONNECTIVITY_THRESHOLD[role_name] || DEFAULT_CONNECTIVITY_THRESHOLD)
      end
      self.mentor_request_wait_time = PercentMetric.new(
        MENTOR_REQUEST_WAIT_TIME_THRESHOLD, {
          :unit => 'day',
          :inverted => true,
          :minimum => MENTOR_REQUEST_WAIT_TIME_MINIMUM,
          :maximum => MENTOR_REQUEST_WAIT_TIME_MAXIMUM
        })
    end

    def compute
      self.role_map.each do |role_name, role_id|
        total_users = self.program.send("#{role_name}_users").active.size
        if total_users == 0
          self.percent_metrics[role_name].update_metric(nil)
        else
          connected_users = Connection::Membership.joins(:group).
                            where(connection_memberships: {role_id: role_id}).
                            where(groups: {program_id: self.program.id, status: Group::Status::ACTIVE_CRITERIA}).
                            select("DISTINCT connection_memberships.user_id").count
          self.percent_metrics[role_name].update_metric(connected_users.to_f / total_users)
        end
      end

      # Request average wait time computation.
      unless self.program.matching_by_admin_alone?
        avg = MentorRequest.where(:program_id => self.program.id).average("TIMESTAMPDIFF(SECOND, created_at, IF(status = #{AbstractRequest::Status::NOT_ANSWERED}, UTC_TIMESTAMP, updated_at))").to_f
        avg = avg.zero? ? nil : avg / (60 * 60 * 24) # Check if no mentor requests present.
      else
        avg = nil
      end

      self.mentor_request_wait_time.update_metric(avg)
    end
  end
end