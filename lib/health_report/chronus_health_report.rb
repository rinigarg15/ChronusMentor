class HealthReport::ChronusHealthReport

  attr_accessor :orgs, :progs, :aggregate, :prog_data

  def initialize(row1_time, row2_time, active)
    self.prog_data = {}

    self.orgs = Organization.where(active: active).includes(:translations).order("programs.created_at DESC").select(:id, :active, :created_at, :account_name)
    self.progs = Program.includes(:translations).select(:id, :root, :created_at, :parent_id, :program_type, :number_of_licenses)

    self.aggregate = {
      registered: {
        total: User.active_or_pending.select("id, program_id, created_at").group_by(&:program_id),
        last_t1: User.active_or_pending.where("created_at < ?", row1_time.ago).select("id, program_id, created_at").group_by(&:program_id),
        last_t2: User.active_or_pending.where("created_at < ?", row2_time.ago).select("id, program_id, created_at").group_by(&:program_id)
      },
      connected: {
        total: User.joins(:groups).active_or_pending.where('groups.closed_at IS NULL').select("users.id, users.program_id").group_by(&:program_id),
        last_t1: get_connected_users(row1_time.ago),
        last_t2: get_connected_users(row2_time.ago)
      },
      active_connected: {
        total: get_active_connected_users(row1_time.ago, Time.now()),
        last_t1: get_active_connected_users((2 * row1_time).seconds.ago, row1_time.ago),
        last_t2: get_active_connected_users((2 * row2_time).seconds.ago, row2_time.ago)
      },
      online_active: {
        total: get_active_users(row1_time.ago, Time.now()),
        last_t1: get_active_users((2 * row1_time).seconds.ago, row1_time.ago),
        last_t2: get_active_users((2 * row2_time).seconds.ago, row2_time.ago)
      }
    }
  end

  def compute_data
    self.progs.each do |pro|
      total_users = get_value(self.aggregate[:registered][:total][pro.id])
      connected_users = get_value(self.aggregate[:connected][:total][pro.id])

      self.prog_data[pro.id] = {
        registered: prepare_and_compute(:registered, pro.id, pro.number_of_licenses),
        connected: prepare_and_compute(:connected, pro.id, total_users),
        active_connected: prepare_and_compute(:active_connected, pro.id, connected_users),
        online_active: prepare_and_compute(:online_active, pro.id, total_users)
      }
    end
  end

  def generate_csv(t1, t2)
    CSV.generate do |csv|

      csv << ["Account", "Organiztion", "Program", "Start date", "Program Type","Number of licenses",
       "Total Registered", "% of number of licenses", "% change from last #{t1}", "% change from last #{t2}",
       "Connected", "% of Registered", "% change from last #{t1}", "% change from last #{t2}",
       "Actively Connected", "% of Connected", "% change from last #{t1}", "% change from last #{t2}",
       "Regular users to portal", "% of Registered", "% change from last #{t1}", "% change from last #{t2}"
      ]

      self.orgs.each do |org|
        progs = self.progs.select{|p| p.parent_id == org.id}
        progs.each do |pro|
          arr = [org.account_name.to_s, org.name, pro.name, DateTime.localize(pro.created_at, format: :full_display_no_time), pro.program_type, pro.number_of_licenses]
          [:registered, :connected, :active_connected, :online_active].each do |key|
            subarray = []
            [:total, :percent_reached, :percent_change_t1, :percent_change_t2].each do |sub_key|
              val = self.prog_data[pro.id][key][sub_key]
              subarray << (val ? val : "NA")
            end
            arr << subarray
          end
          csv << arr.flatten
        end
      end
    end
  end

  private

  def get_connected_users(t1)
    User.joins(:groups).active_or_pending.where(
      'connection_memberships.created_at < ? AND 
      (groups.closed_at IS NULL OR groups.closed_at > ?)', t1, t1).
    select("users.id, users.program_id").group_by(&:program_id)
  end

  def get_active_connected_users(t1, t2)
    User.joins(:activity_logs).active_or_pending.where(
      'activity_logs.activity = ? AND activity_logs.created_at BETWEEN ? AND ?',
      ActivityLog::Activity::MENTORING_VISIT, t1, t2).
    select("users.id, users.program_id").group_by(&:program_id)
  end

  def get_active_users(t1, t2)
    User.joins(:activity_logs).active_or_pending.where(
      'activity_logs.created_at BETWEEN ? AND ?', t1, t2)
    .select("users.id, users.program_id").group_by(&:program_id)
  end

  def get_value(val)
    val ? (val.is_a?(Array) ? val.uniq.size.to_f : val.to_f) : 0.0
  end

  def compute_column(cur_value, last_month_value, last_quarter_value, compare_metric)
    change_1 = cur_value - last_month_value
    change_2 = cur_value - last_quarter_value
    {
      total: cur_value.to_i.to_s,
      percent_reached: (compare_metric > 0 && cur_value > 0) ? ((cur_value/compare_metric)*100).round : nil,
      change_t1: change_1,
      percent_change_t1: (last_month_value > 0) ? ((change_1/last_month_value)*100).round : nil,
      change_t2: change_2,
      percent_change_t2: (last_quarter_value > 0) ? ((change_2/last_quarter_value)*100).round : nil
    }
  end
  
  def prepare_and_compute(key, pro_id, compare_metric)
    cur_value = get_value(self.aggregate[key][:total][pro_id])
    last_t1 =   get_value(self.aggregate[key][:last_t1][pro_id])
    last_t2 =   get_value(self.aggregate[key][:last_t2][pro_id])
    compute_column(cur_value, last_t1, last_t2, get_value(compare_metric))
  end

end