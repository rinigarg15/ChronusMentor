require_relative './../../../test_helper'

class HealthReport::GrowthTest < ActiveSupport::TestCase
  def test_growth_metrics
    program = programs(:albers)
    role_map = role_map_for(program)
    growth = HealthReport::Growth.new(program, role_map)

    RoleReference.where(ref_obj_type: "User").update_all({:created_at => 2.months.ago})
    create_user(:name => "mentor_one", :role_names => RoleConstants::MENTOR_NAME)
    create_user(:name => "mentor_two", :role_names => RoleConstants::MENTOR_NAME)
    create_user(:name => "student_one", :role_names => RoleConstants::STUDENT_NAME)
    create_user(:name => "both_mentor_and_student", :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    
    assert_equal [true, true, true], growth.history_data.values.first(role_map.size).map{|metric| metric.last_month.blank?}

    growth.compute
    assert_equal role_map.keys.map{|role_name| program.send("#{role_name}_users").active.size}, growth.history_data.values.first(role_map.size).map{|metric| metric.value}

    programs(:albers).update_attribute :created_at, 2.months.ago - 2.days
    RoleReference.where(ref_obj_type: "User").update_all({:created_at => (2.months.ago - 1.days)})
    create_user(:name => "mentor_three", :role_names => RoleConstants::MENTOR_NAME)
    create_user(:name => "student_two", :role_names => RoleConstants::STUDENT_NAME)
    create_user(:name => "both_mentor_and_student_two", :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    growth.compute
    growth.compute_summary_data

    assert_equal role_map.keys.map{|role_name| program.send("#{role_name}_users").active.size}, growth.graph_data.values.first(role_map.size).map{|metric| metric.last}
  end
  
  def test_growth_graph
    program = programs(:albers)
    role_map = role_map_for(program)
    growth = HealthReport::Growth.new(program, role_map)
    prog_start = 1.months.ago
    program.update_attribute :created_at, prog_start
    RoleReference.where(ref_obj_type: "User").update_all(:created_at => prog_start + 15.days)

    day_map = {}
    sum_map = {}
    graph_data_map = {}
    (role_map.keys + [:connection]).each do |k| 
      day_map[k] = Hash.new(0)
      graph_data_map[k] = []
      sum_map[k] = 0
    end
    # compute data related to users
    role_map.each do |role_name, role_id|
      user_ids = program.send("#{role_name}_users").active.pluck(:id)
      user_ids.first(10).each do |user_id|
        n = rand(30)
        RoleReference.where(ref_obj_type: "User", ref_obj_id: user_id, role_id: role_id).update_all(:created_at => prog_start + n.days)
        day_map[role_name][n] += 1 
      end
      day_map[role_name][15] += user_ids.size - day_map[role_name].values.sum
    end
    
    # compute data related to connection
    2.upto(9) do |i|
      create_group(:mentor => users("mentor_#{i}".to_sym), :students => [users("student_#{i}".to_sym)])
    end
    program.groups.active.update_all(:created_at => prog_start + 15.days)
    active_group_ids = program.groups.active.pluck(:id)
    active_group_ids.first(10).each do |group_id|
      n = rand(30)
      Group.find(group_id).update_attribute(:created_at, prog_start + n.days)
      day_map[:connection][n] += 1
    end
    day_map[:connection][15] += active_group_ids.size - day_map[:connection].values.sum


    step_fraction = 1.0
    start_step = Program.select("ROUND((TO_DAYS(created_at) * #{step_fraction})) AS step_num").find(growth.program.id)['step_num'].to_i
    current_db_time = Time.now.utc.to_s(:db)
    last_step = ActiveRecord::Base.connection.select_value("select ROUND((TO_DAYS('#{current_db_time}') * #{step_fraction}))").to_i


    0.upto(last_step - start_step) do |i|
     (role_map.keys + [:connection]).each do |k|
        sum_map[k] += day_map[k][i]
        graph_data_map[k][i] = sum_map[k]
     end
    end
    growth.compute
    growth.compute_summary_data
    assert_equal graph_data_map.values.flatten, growth.graph_data.values.flatten
  end
  
  def test_create_unfiorm_increasing_array
    program = programs(:albers)
    role_map = role_map_for(program)
    growth = HealthReport::Growth.new(program, role_map)
    assert_equal [0, 2.5, 5, 7.5, 10], growth.create_unfiorm_increasing_array(5, 0, 10)
    assert_equal [0, 2.75, 5.5, 8.25, 11], growth.create_unfiorm_increasing_array(5, 0, 11)
    assert_equal [1, 1.5, 2, 2.5, 3], growth.create_unfiorm_increasing_array(5, 1, 3)
    assert_equal [1, 2, 3], growth.create_unfiorm_increasing_array(5, 1, 3, 1)
    assert_equal [1, 10.5, 20], growth.create_unfiorm_increasing_array(3, 1, 20)
    assert_equal [7, 7, 7, 7, 7], growth.create_unfiorm_increasing_array(5, 7, 7)
    assert_equal [7], growth.create_unfiorm_increasing_array(5, 7, 7, 1)
    assert_equal [3], growth.create_unfiorm_increasing_array(1, 3, 8)
  end

  private

  def role_map_for(program)
    role_map = {}
    program.roles_without_admin_role.each{|role| role_map[role.name] = role.id }
    role_map
  end
end
