require_relative './../../test_helper.rb'

class Connection::AnswerTest < ActiveSupport::TestCase

  def test_belongs_to_and_should_have_group
    assert_no_difference 'Connection::Answer.count' do
      assert_multiple_errors([:field => :group]) do
        @ans = Connection::Answer.create!(
          :question => common_questions(:string_connection_q),
          :answer_text => 'hello')
      end
    end

    assert_difference 'Connection::Answer.count' do
      assert_nothing_raised do
        @ans = Connection::Answer.create!(
          :question => common_questions(:string_connection_q),
          :group => groups(:group_2),
          :answer_text => 'hello')
      end
    end

    assert_equal groups(:group_2), @ans.group
  end

  def test_uniquness_of_group
    assert_no_difference 'Connection::Answer.count' do
      assert_multiple_errors([:field => :group]) do
        @ans = Connection::Answer.create!(
          :question => common_questions(:string_connection_q),
          :group => groups(:mygroup),
          :answer_text => 'hello')
      end
    end
  end
  
end
