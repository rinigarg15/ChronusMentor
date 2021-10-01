require_relative './../../test_helper.rb'

class ManagerObserverTest < ActiveSupport::TestCase

  def test_member_cannot_be_his_own_manager
    manager_1 = managers(:manager_1)
    assert_nothing_raised do
      manager_1.email = "robert@example.com"
      manager_1.save!
    end
  end

  def test_after_save
    manager_1 =  managers(:manager_1)

    program = programs(:albers)
    set_program_prevent_manager_matching(program, true)

    managerobserver1 = ManagerObserver
    ManagerObserver.expects(:delay).returns(managerobserver1)
    managerobserver1.expects(:handle_profile_update).with(manager_1.managee.id, manager_1.profile_answer.profile_question.id)
    assert_nothing_raised do
      manager_1.email = "rahim@example.com"
      manager_1.save!
      assert_equal manager_1.managee, members(:f_mentor)
    end

    set_program_prevent_manager_matching(program, false)
    managerobserver2 = ManagerObserver
    ManagerObserver.expects(:delay).returns(managerobserver2).never    
    assert_nothing_raised do
      manager_1.email = "rahim@example.com"
      manager_1.save!
      assert_equal manager_1.managee, members(:f_mentor)
    end
    assert_nothing_raised do
      manager_1.first_name = "New First Name"
      manager_1.save!
    end
  end

  def test_after_destroy
    manager_1 =  managers(:manager_1)
    program = programs(:albers)
    set_program_prevent_manager_matching(program, true)
    managerobserver1 = ManagerObserver
    ManagerObserver.expects(:delay).returns(managerobserver1)
    managerobserver1.expects(:handle_profile_update).with(manager_1.managee.id, manager_1.profile_answer.profile_question.id, true)
    assert_nothing_raised do
      manager_1.destroy
    end
  end

  def test_handle_profile_update
    member = members(:f_mentor)
    ManagerObserver.expects(:perform_delta_index)
    ManagerObserver.handle_profile_update(member.id, [])
  end

  private
   def set_program_prevent_manager_matching(program, value)
    program.update_attributes(:prevent_manager_matching => value)
   end
end