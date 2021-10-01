require_relative './../test_helper.rb'

class ManagerTest < ActiveSupport::TestCase

  def test_valid_member_id
    user = users(:mentor_3)
    question = profile_questions(:manager_q)

    user.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    assert_difference('Manager.count') do
      manager1 = create_manager(user.member, question, :first_name => 'a', :last_name => 'b', :email => 'manager@example.com', :member_id => 1)
      assert_nil manager1.member_id
    end

    user.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    assert_difference('Manager.count') do
      manager2 = create_manager(user.member, question, :first_name => 'a', :last_name => 'b', :email => 'ram@example.com', :member_id => 1)
      assert_equal manager2.member_id, 1
    end
  end

  def test_has_one_managee
    assert_equal managers(:manager_1).managee, members(:f_mentor)
  end

  def test_belongs_to_member
    assert_nil managers(:manager_1).member
    assert_equal managers(:manager_3).member, members(:rahim)
  end

  def test_in_organization_scope
    assert_equal_unordered Manager.in_organization(Organization.find(1)), Manager.all
    assert_equal_unordered Manager.in_organization(Organization.find(2)), []
  end

  def test_create_new_manager_should_create_answer
    user = users(:mentor_3)
    question = profile_questions(:manager_q)
    user.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy

    assert_nil user.answer_for(question)

    assert_difference('ProfileAnswer.count') do
      assert_difference('Manager.count') do
        create_manager(user.member, question, :first_name => 'a', :last_name => 'b', :email => 'manager@example.com')
      end
    end
    assert user.answer_for(question)
    manager = user.answer_for(question).manager
    assert_equal "a", manager.first_name
    assert_equal "b", manager.last_name
    assert_equal "a b, manager@example.com",user.answer_for(question).answer_text
  end

  def test_updating_manager_attributes_should_change_answer_text_value
    user = users(:mentor_3)
    question = profile_questions(:manager_q)
    answer = user.answer_for(question)
    manager = answer.manager

    assert_equal "Manager2", manager.first_name
    assert_equal "Manager2 Name2, manager2@example.com",answer.answer_text

    manager.update_attributes(:first_name => "New")

    assert_equal "New", manager.first_name
    assert_equal "New Name2, manager2@example.com",answer.reload.answer_text
  end

  def test_updating_manager_email_field_should_change_member_id
    user = members(:student_1)
    question = profile_questions(:manager_q)
    answer = user.answer_for(question)
    manager = answer.manager
    assert_equal manager.member_id, 7

    manager.update_attributes(:email => "nonexisting@example.com")
    assert_nil manager.member_id

    manager.update_attributes(:email => "userram@example.com")
    assert_equal manager.member_id, 6
  end

  def test_destroying_manager
    user = users(:f_mentor)
    question = profile_questions(:manager_q)
    answer = user.answer_for(question)

    manager = answer.manager

    assert_difference('ProfileAnswer.count', -1) do
      assert_difference('Manager.count', -1) do
        manager.destroy
      end
    end

    assert_nil user.answer_for(question)
  end

  def test_update_member_id
    manager_1 = managers(:manager_1)

    manager_1.email = "ram@example.com"
    manager_1.update_member_id
    assert_equal manager_1.member_id, 1

    manager_1.email = "nonexisting@example.com"
    manager_1.update_member_id
    assert_nil manager_1.member_id

    manager_1.update_member_id(:manager_member_id => 10)
    assert_equal manager_1.member_id, 10

    manager_1.email = "ram@example.com"
    manager_1.update_member_id(:organization_id => 1)
    assert_equal manager_1.member_id, 1
  end

  def test_column_names_for_question_for_non_publication_question
    question = profile_questions(:profile_questions_1)
    assert_equal [], Manager.column_names_for_question(question)
  end

  def test_column_names_for_question_for_manager_question
    question = profile_questions(:manager_q)
    expected = [
      "Current Manager-First name",
      "Current Manager-Last name",
      "Current Manager-Email"
    ]
    assert_equal expected, Manager.column_names_for_question(question)
  end

  def test_manager_email_should_have_valid_format_ignore_domain
    user = members(:student_1)
    question = profile_questions(:manager_q)
    answer = user.answer_for(question)
    manager = answer.manager

    manager.email = "balaji@domaindoesnotexists.com"
    assert manager.save

    manager.email = "invalid.formate.email"
    assert_false manager.save
    assert_equal ["is not a valid email address."], manager.errors.messages[:email]
  end

  def test_versioning
    manager = managers(:manager_1)
    assert manager.versions.empty?
    assert_difference "manager.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        manager.update_attributes(member_id: 10)
      end
    end

    user = users(:mentor_3)
    question = profile_questions(:manager_q)
    answer = user.answer_for(question)
    manager = answer.manager

    assert_difference "manager.versions.size", 1 do
      assert_difference "answer.versions.size", 1 do
        assert_difference "ChronusVersion.count", 2 do
          manager.update_attributes(first_name: "New")
        end
      end
    end
  end
end