require_relative './../../../test_helper.rb'

class Api::V2::ProfileFieldsPresenterTest < ActiveSupport::TestCase
  include AppConstantsHelper

  def setup
    super
    update_profile_question_types_appropriately
    @organization = programs(:albers).organization
    @presenter = Api::V2::ProfileFieldsPresenter.new(nil,@organization)
  end

  def test_list_should_success_with_skype_enabled
    expected_profile_questions = @organization.profile_questions.where(question_type: [ProfileQuestion::Type::MULTI_EXPERIENCE, ProfileQuestion::Type::SKYPE_ID])
    exp_profile_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE)[1]
    question_choices_hash = {}
    profile_questions(:student_single_choice_q).question_choices.each do |qc|
      question_choices_hash[qc.text] = qc.id
    end
    exp_profile_question.conditional_question_id = profile_questions(:student_single_choice_q).id
    exp_profile_question.update_conditional_match_choices!([question_choices_hash["opt_1"],question_choices_hash["opt_2"]])
    exp_profile_question.save!
    Organization.any_instance.expects(:profile_question_ids).returns(expected_profile_questions.pluck(:id))
    result = @presenter.list
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 4, result[:data].size
    skype_questions = result[:data].select { |que| que[:label] ==  "Skype ID"}
    assert_equal 1, skype_questions.size
    skype_question = skype_questions.first
    assert_equal skype_question[:label], "Skype ID"
    assert_equal skype_question[:type], "Skype ID"
    assert_equal skype_question[:programs], {"Albers Mentor Program"=>["mentor", "mentee"], "NWEN"=>["mentor", "mentee"], "Moderated Program"=>["mentor", "mentee"], "No Mentor Request Program"=>["mentor", "mentee"], "Project Based Engagement"=>["mentor", "mentee"]}
    assert_equal skype_question[:description], "Including Skype id in your profile would allow your connected members to call you from the mentoring area. If you face trouble receiving Skype calls, please check your privacy settings."
    location_based_questions = result[:data].select { |que| que[:type] == "Experience" }
    assert_equal location_based_questions.count, 3
    location_based_question = location_based_questions[1]
    assert_equal location_based_question[:label], "Current Experience"
    assert_equal location_based_question[:type], "Experience"
    assert_equal location_based_question[:programs], {"Albers Mentor Program"=>["mentor"]}
    assert_equal location_based_question[:condition_to_show], {:id=>expected_profile_questions.where(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE)[1].conditional_question_id, :answer=>"opt_1,opt_2"}
  end

  def test_list_should_success_with_skype_disabled
    @organization.enable_feature(FeatureName::SKYPE_INTERACTION, false)
    expected_profile_questions = @organization.profile_questions.where(question_type: [ProfileQuestion::Type::MULTI_EXPERIENCE, ProfileQuestion::Type::SKYPE_ID])
    Organization.any_instance.expects(:profile_questions).returns(expected_profile_questions)
    result = @presenter.list
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 3, result[:data].size
    skype_questions = result[:data].select { |que| que[:label] ==  "Skype ID"}
    assert_equal 0, skype_questions.size
    skype_question = skype_questions.first
    location_based_questions = result[:data].select { |que| que[:type] == "Experience" }
    assert_equal location_based_questions.count, 3
    location_based_question = location_based_questions[1]
    assert_equal location_based_question[:label], "Current Experience"
    assert_equal location_based_question[:type], "Experience"
    assert_equal location_based_question[:programs], {"Albers Mentor Program"=>["mentor"]}
  end

  def test_list_should_success_with_params_with_parent_field_id_and_answer_text_under_conditional_answer_matched
    expected_profile_questions = @organization.profile_questions.first(1)
    ProfileQuestion.any_instance.expects(:dependent_questions).returns(expected_profile_questions)
    ProfileQuestion.any_instance.expects(:conditional_answer_matches_any_of_conditional_choices?).returns(true)
    result = @presenter.list(parent_field_id: ProfileQuestion.first.id, answer_text: "a,b")
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size
    assert_equal expected_profile_questions.collect(&:id), result[:data].collect{ |que| que[:id] }
  end

  def test_list_should_success_with_params_with_parent_field_id_and_answer_text_under_conditional_answer_doesnot_match
    expected_profile_questions = @organization.profile_questions.first(1)
    ProfileQuestion.any_instance.expects(:dependent_questions).returns(expected_profile_questions)
    ProfileQuestion.any_instance.expects(:conditional_answer_matches_any_of_conditional_choices?).returns(false)
    result = @presenter.list(parent_field_id: ProfileQuestion.first.id, answer_text: "a,b")
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 0, result[:data].size
  end

  def test_list_should_success_with_params_with_parent_field_id_and_answer_text_under_parent_profile_question_doesnot_exist
    result = @presenter.list(parent_field_id: 999999, answer_text: "a,b") # random profile question id which doesnot exist in database
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 0, result[:data].size
  end

  def test_list_should_success_with_params_with_parent_field_id_and_answer_text_not_present
    result = @presenter.list(parent_field_id: ProfileQuestion.first.id)
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 0, result[:data].size
  end

  def test_list_should_success_with_params_with_parent_field_id_with_answer_text_not_present_and_parent_profile_question_doesnot_exist
    result = @presenter.list(parent_field_id: 999999) # random profile question id which doesnot exist in database
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 0, result[:data].size
  end

  def test_list_should_success_with_params_with_answer_text_and_parent_field_id_not_present
    result = @presenter.list(answer_text: "a,b")
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 0, result[:data].size
  end
end
