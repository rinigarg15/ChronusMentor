require_relative './../../test_helper.rb'

class ReorderServiceTest < ActiveSupport::TestCase

  def startup
    Object.const_set("Row", Class.new(ActiveRecord::Base) {} )
  end

  def shutdown
    ActiveRecord::Base.direct_descendants.delete(Row)
    Object.send(:remove_const, "Row")
  end

  def setup_db
    ActiveRecord::Base.connection.create_table :rows, force: true, temporary: true do |t|
      t.column :position, :integer, default: 0
    end
  end

  def teardown_db
    ActiveRecord::Base.connection.drop_table(:rows, temporary: true)
  end

  def setup
    super
    setup_db
  end

  def teardown
    super
    teardown_db
  end

  def test_reorder
    r1 = Row.create!(position: 1)
    r2 = Row.create!(position: 10)
    r3 = Row.create!(position: 20)
    r4 = Row.create!(position: 21)

    assert_raise(NoMethodError) do
      ReorderService.new(Row.all).reorder([r2.id, r4.id, r1.id, r3.id, "some thing that raises an exception"])
    end

    assert_equal 1, r1.reload.position
    assert_equal 10, r2.reload.position
    assert_equal 20, r3.reload.position
    assert_equal 21, r4.reload.position

    ReorderService.new(Row.all).reorder(["#{r2.id}", r4.id, r1.id, r3.id])

    assert_equal 1, r2.reload.position
    assert_equal 2, r4.reload.position
    assert_equal 3, r1.reload.position
    assert_equal 4, r3.reload.position
  end

  def test_reorder_with_base_postion
    r1 = Row.create!(position: 1)
    r2 = Row.create!(position: 10)
    r3 = Row.create!(position: 20)
    r4 = Row.create!(position: 21)

    assert_raise(NoMethodError) do
      ReorderService.new(Row.all).reorder([r2.id, r4.id, r1.id, r3.id, "some thing that raises an exception"], 0)
    end

    assert_equal 1, r1.reload.position
    assert_equal 10, r2.reload.position
    assert_equal 20, r3.reload.position
    assert_equal 21, r4.reload.position

    base_position = 2
    ReorderService.new(Row.all).reorder(["#{r2.id}", r4.id, r1.id, r3.id], base_position)

    assert_equal 3, r2.reload.position
    assert_equal 4, r4.reload.position
    assert_equal 5, r1.reload.position
    assert_equal 6, r3.reload.position
  end
end