module HealthReport
  # Program Growth metrics
  class Growth
    SEPARATOR = ','

    MEMBERSHIP_REQUEST_WAIT_TIME_THRESHOLD = 5
    MEMBERSHIP_REQUEST_WAIT_TIME_MINIMUM   = 0
    MEMBERSHIP_REQUEST_WAIT_TIME_MAXIMUM   = 10

    GROWTH_X_NUM_POINTS = 5
    GROWTH_Y_NUM_POINTS = 5

    attr_accessor :program, :graph_data, :history_data,
                  :role_map, :membership_request_wait_time

    # Constructor
    #
    # Params:
    # * <tt>program</tt> : Program to compute the Growth report for.
    #
    def initialize(program, role_map)
      self.program = program
      self.role_map = role_map
      self.history_data, self.graph_data = {}, {}
      (self.role_map.keys + [:connection]).each do |key|
        self.history_data[key] = HistoryMetric.new
        self.graph_data[key] = []
      end
      self.membership_request_wait_time = PercentMetric.new(MEMBERSHIP_REQUEST_WAIT_TIME_THRESHOLD,
        {minimum: MEMBERSHIP_REQUEST_WAIT_TIME_MINIMUM,
         maximum: MEMBERSHIP_REQUEST_WAIT_TIME_MAXIMUM,
         inverted: true,
         unit: 'day'
        })
    end

    # Returns whether the graph has no data points.
    def no_graph_data?
      all_values = self.graph_data.values.flatten.uniq
      all_values.empty? || all_values == [0.0]
    end

    def compute
      compute_detailed_data
    end

    # Returns Array of +num_points+ points to use for the X-axis.
    def x_points
      arr = create_unfiorm_increasing_array(GROWTH_X_NUM_POINTS, self.program.created_at, Time.now, 1.day)
      arr.collect{|d| DateTime.localize(d, format: :day_month)}
    end

    # Returns Array of +num_points+ points to use for the Y-axis.
    def y_points
      all_points = self.graph_data.values.flatten
      arr = create_unfiorm_increasing_array(GROWTH_Y_NUM_POINTS, all_points.min, all_points.max, 1)
      arr.collect(&:round)
    end

    # Constructs a new Array with +size+ elements where the first value is
    # +start_val+ and the end value is +end_val+. Inbetween values are derived
    # by applying a fixed delta based on the end_val, start_val and size.
    #
    # It might turn out that the values that the resulting array are too close to
    # each other (delta too small). If +min_delta+ passed, it ensures that the
    # delta is at least +min_delta+. But, in that case, we may return less than
    # +size+ number of values in the array.
    #
    def create_unfiorm_increasing_array(size, start_val, end_val, min_delta = nil)
      return [start_val] if size == 1

      num_jumps = size - 1
      range = end_val - start_val    # Full range of array values
      delta = range.to_f / num_jumps # Uniform delta between each of the entries

      # If there is too narrow data to form 'size' points, use min_delta as
      # the delta
      if min_delta && (delta < min_delta)
        # Find the number of points when the delta is 'min_delta'
        num_jumps = ((end_val - start_val) / min_delta)
        delta = min_delta
      end

      new_array = []

      0.upto(num_jumps) do |step|
        incr = step * delta
        new_array << start_val + incr
      end

      return new_array
    end

     # Calculate data points for the growth graph.
    def compute_summary_data
      current_db_time = Time.now.utc.to_s(:db)

      # Start period of the program in terms of.
      start_step = Program.select("TO_DAYS(created_at) AS step_num").find(self.program.id)['step_num'].to_i
      last_step = ActiveRecord::Base.connection.select_value("select TO_DAYS('#{current_db_time}')").to_i

      if self.program.ongoing_mentoring_enabled?
        connection_data = self.program.groups.active.select("TO_DAYS(groups.created_at) AS step_num").group_by{|connection| connection['step_num'].to_i}

        connection_data_array = []
        start_step.upto(last_step) do |step|
          connection_data_array << connection_data[step].try(:size)
        end

        self.graph_data[:connection] = cumulative_array(connection_data_array)
      end

      # retreiving users related data

      users_data = {}
      self.role_map.values.each{|role_id| users_data[role_id] = Hash.new(0)}
      RoleReference.joins("LEFT JOIN users ON users.id = role_references.ref_obj_id AND role_references.ref_obj_type = 'User'").select("TO_DAYS(role_references.created_at) AS step_num, role_references.ref_obj_id, role_references.role_id").where(role_id: self.role_map.values).where("users.state IN (?)", [User::Status::ACTIVE]).each{|x| users_data[x['role_id']][x['step_num']] += 1}

      self.role_map.each do |role_name, role_id|
        data_array = []
        start_step.upto(last_step).each_with_index do |step|
          data_array << users_data[role_id][step]
        end
        self.graph_data[role_name] = cumulative_array(data_array)
      end
    end

    private

    # Calculate last value and change of mentor and student counts.
    def compute_detailed_data
      total_count_hash, last_month_count_hash = Hash.new(0), Hash.new(0)
      scope = RoleReference.joins("LEFT JOIN users ON users.id = role_references.ref_obj_id AND role_references.ref_obj_type = 'User'").select("role_id, GROUP_CONCAT(ref_obj_id) AS user_ids").where(role_id: self.role_map.values).where("users.state IN (?)", [User::Status::ACTIVE]).group(:role_id)
      scope.each{|x| total_count_hash[x.role_id] = x.user_ids.split(SEPARATOR).size}
      scope.where('role_references.created_at > ?', 1.month.ago.utc.to_s(:db)).each{|x| last_month_count_hash[x.role_id] = x.user_ids.split(SEPARATOR).size}

      self.role_map.each do |role_name, role_id|
        self.history_data[role_name].update_metric(total_count_hash[role_id], last_month_count_hash[role_id])
      end
      self.history_data[:connection].update_metric(self.program.groups.active.count, self.program.groups.recent(1.month.ago).active.count)

      avg = MembershipRequest.where(program_id: self.program.id).average("TIMESTAMPDIFF(SECOND, created_at, IF(status = #{MembershipRequest::Status::UNREAD}, UTC_TIMESTAMP, updated_at))").to_f

      self.membership_request_wait_time.update_metric(avg.zero? ? nil : avg / (60 * 60 * 24))
    end

    # Adds a new data point to the given graph.
    def add_record(graph_name, x_point, y_point)
      self.graph_data[graph_name][x_point] = y_point
    end

    # Returns an array with the values in +data_array+ cumulated.
    #
    #   [5, 2, 11, 9]     #=> [5, 7, 18, 27]
    #   [1, 3, 4, nil, 7] #=> [1, 4, 8, 8, 15]
    #
    def cumulative_array(data_array)
      sum = 0
      data_array.map{|x| sum += (x || 0)}
    end
  end
end