Then /^I stub to get valid mentor lists$/ do
  PreferenceBasedMentorList.any_instance.stubs(:meets_number_of_choices_creteria?).returns(true)
  PreferenceBasedMentorList.any_instance.stubs(:meets_number_of_mentors_answered_creteria?).returns(true)
end

Then /^I stub to get some mentor lists$/ do
  PreferenceBasedMentorListsRecommendationService.any_instance.stubs(:has_recommendations?).returns(true)
  pbml1 = PreferenceBasedMentorList.new(ref_obj: Location.find_by(city: 'Chennai'), profile_question: ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first, weight: 1.0)
  qct = QuestionChoice::Translation.find_by(text: "Male"); qc = QuestionChoice.find(qct.question_choice_id); pq = qc.ref_obj
  pbml2 = PreferenceBasedMentorList.new(ref_obj: qc, profile_question: pq, weight: 1.0)
  mentor_lists = [pbml1, pbml2]
  PreferenceBasedMentorListsRecommendationService.any_instance.stubs(:get_ordered_lists).returns(mentor_lists)
end

Then /^I should see "([^\"]*)" in Location filter$/ do |value|
  pq = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
  location_filter_id = "#search_filters_location_#{pq.id}_name"
  assert page.evaluate_script("jQuery('#{location_filter_id}').val() == '#{value}'")
end

Then /^I verify gender filter$/ do
  qct = QuestionChoice::Translation.find_by(text: "Male"); qc = QuestionChoice.find(qct.question_choice_id); pq = qc.ref_obj
  steps %{
    Then I follow "More filters" 
  }
  page.execute_script("jQuery('#sfpq_#{pq.id}_0').closest('.filter_item').find('.btn-link').click()")
  steps %{
    Then the "sfpq_#{pq.id}_0" checkbox_id should be checked
    Then the "sfpq_#{pq.id}_1" checkbox_id should not be checked
  }
end

Given /^I visit home page with popular categories experiment enabled$/ do
  visit root_path(root: "albers", show_preference_categories: true, from_first_visit: true)
end