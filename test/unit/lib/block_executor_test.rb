require_relative './../../test_helper.rb'

class BlockExecutorTest < ActiveSupport::TestCase

  def teardown
    block_executor_parents = BlockExecutor.instance_variable_get(:@block_executor_parents)
    assert block_executor_parents.empty? || block_executor_parents.nil?
    super
  end

  def test_iterate
    sum = 0

    Airbrake.expects(:notify).never
    BlockExecutor.iterate_fail_safe(1..5) { |i| sum += i }
    assert_equal 15, sum
  end

  def test_iterate_with_error
    sum = 0

    Airbrake.expects(:notify).with("FailSafeLoop Error -> Objects: 3, b | Error: i is 3 & j is b").once
    Airbrake.expects(:notify).with("FailSafeLoop Error -> Objects: 4, a | Error: i is 4 & j is a").once
    BlockExecutor.iterate_fail_safe(1..5) do |i|
      BlockExecutor.iterate_fail_safe(['a', 'b']) do |j|
        raise "i is 3 & j is b" if i == 3 && j == 'b'
        raise "i is 4 & j is a" if i == 4 && j == 'a'
        sum += i
      end
    end
    assert_equal 23, sum
  end

  def test_iterate_over_active_record_relation
    Airbrake.expects(:notify).with("FailSafeLoop Error -> Objects: User - 1 | Error: Invalid User").once
    BlockExecutor.iterate_fail_safe(User.where(id: 1)) do
      raise "Invalid User"
    end
  end

  def test_iterate_over_hash
    keys = []
    values = []

    BlockExecutor.iterate_fail_safe(a: 1, b: 2) { |k, v| keys << k; values << v }
    assert_equal [:a, :b], keys
    assert_equal [1, 2], values
  end
end