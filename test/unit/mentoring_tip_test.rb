require_relative './../test_helper.rb'

class MentoringTipTest < ActiveSupport::TestCase

  def test_program_is_required
    assert_no_difference 'MentoringTip.count' do
      assert_raise AuthorizationManager::ProgramNotSetException do
        MentoringTip.create!(:role_names => [RoleConstants::MENTOR_NAME], :message => "Message")
      end
    end
  end

  def test_roles_required
    assert_no_difference 'MentoringTip.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :roles do
        MentoringTip.create!(:program => programs(:albers), :message => "Message")
      end
    end
  end

  def test_message_is_required
    assert_no_difference 'MentoringTip.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
        MentoringTip.create!(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME])
      end
    end
  end

  def test_message_is_max_limit
    string = "h"
    351.times{string += "h"}
    assert_no_difference 'MentoringTip.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
        MentoringTip.create!(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :message => string)
      end
    end
  end

  def test_create_success
    assert_difference 'MentoringTip.count' do
      MentoringTip.create!(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :message => "Message")
    end
  end

  def test_scopes
    MentoringTip.destroy_all
    m1 = MentoringTip.create!(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :message => "Message_1")
    m2 = MentoringTip.create!(:program => programs(:albers), :role_names => [RoleConstants::STUDENT_NAME], :message => "Message 2")
    m3 = MentoringTip.create!(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :message => "Message 3", :enabled => false)
    assert_equal [m3, m1], programs(:albers).mentoring_tips.for_mentors
    assert_equal [m2], programs(:albers).mentoring_tips.for_students
    assert_equal [m2, m1], programs(:albers).mentoring_tips.enabled
  end
end
