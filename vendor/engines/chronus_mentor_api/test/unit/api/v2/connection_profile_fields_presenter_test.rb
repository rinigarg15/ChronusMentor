require_relative './../../../test_helper.rb'

class Api::V2::ConnectionProfileFieldsPresenterTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    @questions = @program.connection_questions
    @presenter = Api::V2::ConnectionProfileFieldsPresenter.new(@program)
  end

  def test_list_should_success_without_params
    result = @presenter.list

    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal @questions.size, result[:data].size

    # make sure we have all groups in output
    expected_keys  = [:id, :label, :type, :choices]
    @questions.each_with_index do |q, q_index|
      q_hash = result[:data][q_index]
      assert_instance_of Hash, q_hash
      expected_keys.each do |expected_key|
        assert q_hash.has_key?(expected_key), "hash should contain #{expected_key.inspect} key"
      end
      assert_equal q.id, q_hash[:id]
      assert_equal q.question_text, q_hash[:label]
      assert_equal q.question_type, q_hash[:type]
      assert_equal q.default_choices.join_by_separator(","), q_hash[:choices]
    end
  end
end