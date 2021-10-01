class CollectRatio
  EXCLUDED_KEYS = ["user", "pending_user", "member", "group", "mentor_role", "mentee_role", "profile_answer", "group_mentoring_mentor_intensive", "group_mentoring_equal_mentor_mentee", "group_mentoring_mentee_intensive", "organization", "program"]
  RATIOS_HEADERS = ["Key", "Parent", "Ratios"]
  SPEC_RATIOS_FILE_NAME = "current_ratios.csv"
  GROWTH_PREDICTOR_FILE_NAME = 'avg_growth_this_quarter.csv'
  ARRAY_ATR = ["percent", "count", "users_count", "dependency", "campaign_management_feature_models", "three_sixty_survey_feature_models", "program_event_feature_models", "project_request_feature_models", "group_mentoring_feature_models"]
  DEFAULT_GROWTH_RATE = 1.25
  attr_accessor :manager

  def initialize
    populator_object = PopulatorManagerIntegrationTest.new()
    @manager = populator_object.initialize_manager({:ignore_test_spec => true})
    @manager.build_graph
    @manager.build_traverse_order
    @counts_ary = []
    @active_organization_ids = Organization.active.pluck(:id)
    @active_program_ids =  Program.where(:parent_id => @active_organization_ids).pluck(:id)
  end

  def write_to_csv(csv_data, file_name)
    CSV.open("#{Rails.root.to_s}/tmp/#{file_name}", "w") do |csv|
      csv_data.each{|row| csv << row}
    end
  end

  def write_to_yaml(data_hash) 
    File.open("#{Rails.root.to_s}/tmp/spec_config.yaml","w") do |h| 
      h.write data_hash.to_yaml
    end
  end

  def get_counts_ary(parent, child_klass, node)
    parent_id = (parent + '_id').to_sym 
    counts_hash = child_klass.select([:id, parent_id]).group_by{|x| x.send(parent_id)}
    parent_klass = @manager.get_class(@manager.nodes[node]['parent'])
    (parent_klass.pluck(:id) - counts_hash.keys).each { |id| counts_hash[id] = [] }

    @counts_ary = if parent.downcase == "organization" || child_klass.name == "Section"
      counts_hash.select{|k,v| @active_organization_ids.include?(k)}.map{|k,v| v.size}
    elsif parent.downcase == "program"
      counts_hash.select{|k,v| @active_program_ids.include?(k)}.map{|k,v| v.size}
    else
      counts_hash.map{|k,v| v.size}
    end
  end

  def data_growth_per_month(month1, month2)
    values = []
    month1.each_with_index do |row, index|
      col = []
      for i in 0..1
        col << row[i]
      end
      for i in 2..4
        col << (month2[index][i].to_f - row[i].to_f).round(2)
      end
      values << col
    end
    values
  end

  def avg_growth_per_quarter(current_data, options={})
    avg_growth = [["name", "parent", "Max_growth", "Avg_growth", "Min_growth", "Max", "Avg", "Min"]]
    current_data.each_with_index do |row, index|
      col = []
      for i in 0..1
        col << row[i]
      end
      for i in 2..4
        col << (options[:default] ? 1.25 : avg_growth_factor(options[:growth_data],current_data, index, i))
      end
      for i in 2..4
        col<< current_data[index][i].to_f * col[i]
      end
      avg_growth << col
    end
    avg_growth
  end

  def update_spec(csv1)
    csv1.each_with_index do |row, index|
      node = @manager.nodes[row[0]]
      data = row[2].split('|').map{|s| s.split(':')}
      data = data[0..0] + data[1..-1].sort_by{|i| i[0].to_i * -1}
      node["percent"] = data.map{|x| x[0].to_i}
      node["count"] = data.map{|x| x[1].to_i}
    end
  end

  def process_spec
    @manager.nodes.each do |key, value|
      ARRAY_ATR.each{|atr| update_array_element(value, atr)}
    end
  end

  def update_array_element(value, atr)
    value[atr] = value[atr].inspect if value[atr].present?
  end

  def avg_growth_factor(growth_data, current_data, row_index, col_index) 
    total_growth = growth_data.map{|growth| growth[row_index][col_index].to_f}.sum
    [((total_growth + current_data[row_index][col_index].to_f)/current_data[row_index][col_index].to_f).round(2), 1.0].max
  end
end
