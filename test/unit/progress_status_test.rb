require_relative './../test_helper.rb'

class ProgressStatusTest < ActiveSupport::TestCase
  def test_belongs_to_ref_obj
    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
    assert_equal users(:f_admin), ps.ref_obj
  end

  def test_ref_obj_presence
    ps = ProgressStatus.new(for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
    ps.save
    assert_false ps.valid?
    assert_equal ["can't be blank"], ps.errors[:ref_obj] 
  end

  def test_maximum_presence_and_is_a_number
    ps = ProgressStatus.new(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION)
    ps.save
    assert_false ps.valid?
    assert_equal ["can't be blank", "is not a number"], ps.errors[:maximum]

    ps = ProgressStatus.new(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: "something")
    ps.save
    assert_false ps.valid?
    assert_equal ["is not a number"], ps.errors[:maximum]
  end

  def test_maximum_greater_than_zero
    ps = ProgressStatus.new(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: -1)
    ps.save
    assert_false ps.valid?
    assert_equal ["must be greater than 0"], ps.errors[:maximum]
  end

  def test_completed_count_greater_than_o_equal_to_zero_less_than_or_equal_to_maximum
    ps = ProgressStatus.new(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100, completed_count: -1)
    ps.save
    assert_false ps.valid?
    assert ps.errors[:completed_count].include?("must be greater than or equal to 0")

    ps = ProgressStatus.new(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100, completed_count: 101)
    ps.save
    assert_false ps.valid?
    assert ps.errors[:completed_count].include?("must be less than or equal to 100")
  end

  def test_percentage
    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
    assert_equal 0, ps.percentage

    ps.update_attribute(:completed_count, 10)
    assert_equal 10, ps.percentage

    ps.update_attribute(:completed_count, 100)
    assert_equal 100, ps.percentage

    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 3)
    assert_equal 0, ps.percentage
    
    ps.update_attribute(:completed_count, 1)
    assert_equal 33, ps.percentage

    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 1000)
    assert_equal 0, ps.percentage

    ps.update_attribute(:completed_count, 999)
    assert_equal 99, ps.percentage
  end

  def test_completed
    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
    assert_false ps.completed?

    ps.update_attribute(:completed_count, 100)
    assert ps.completed?
  end
end