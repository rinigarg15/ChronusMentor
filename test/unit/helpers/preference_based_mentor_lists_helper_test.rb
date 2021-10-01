require_relative "./../../test_helper.rb"

class PreferenceBasedMentorListsHelperTest < ActionView::TestCase
  def test_get_preference_based_mentor_lists_icon
    qc = QuestionChoice.first
    location = Location.first
    self.stubs(:get_icon_content).with("fa fa-list fa-fw", container_class: "fa fa-circle fa-fw", stack_class: "text-navy").returns('question choice icon')
    self.stubs(:get_icon_content).with("fa fa-map-marker fa-fw", container_class: "fa fa-circle fa-fw", stack_class: "text-navy").returns('location icon')
    assert_equal 'question choice icon', get_preference_based_mentor_lists_icon(qc)
    assert_equal 'location icon', get_preference_based_mentor_lists_icon(location)
  end

  def test_get_preference_based_mentor_lists_title
    qc = QuestionChoice.first
    location = Location.first
    qc.stubs(:text).returns('qc title')
    location.stubs(:city).returns('location title')
    assert_equal 'qc title', get_preference_based_mentor_lists_title(qc)
    assert_equal 'location title', get_preference_based_mentor_lists_title(location)
  end

  def test_get_preference_based_mentor_lists_description
    qc = QuestionChoice.first
    location = Location.first
    assert_equal qc.ref_obj.question_text, get_preference_based_mentor_lists_description(qc)
    assert_equal "app_constant.question_type.Location".translate, get_preference_based_mentor_lists_description(location)
  end

  def test_get_link_to_filtered_mentors_list
    user = users(:f_student)
    list_item = PreferenceBasedMentorList.new
    list_item.ref_obj = locations(:chennai)
    self.stubs(:current_user).returns(user)
    self.stubs(:current_program).returns(user.program)
    self.stubs(:get_applied_availabilty_filters_for_list).returns("availability_filter")
    self.stubs(:get_link_to_filtered_mentors_list_for_choice_based).returns("#choice_based")
    self.stubs(:get_link_to_filtered_mentors_list_for_location_based).returns("#location_based")
    assert_equal "#filters=availability_filter#location_based", get_link_to_filtered_mentors_list(list_item)
  end

  def test_get_link_to_filtered_mentors_list_for_choice_based
    user = users(:f_student)
    choice_based_profile_question = profile_questions(:single_choice_q)
    qc = choice_based_profile_question.question_choices.first
    list_item = PreferenceBasedMentorList.new
    list_item.ref_obj = qc
    list_item.profile_question = choice_based_profile_question
    self.stubs(:current_user).returns(user)
    self.stubs(:current_program).returns(user.program)
    choice_hash = {}
    choice_hash[qc.id] = qc.text
    choice_based_profile_question.stubs(:values_and_choices).returns(choice_hash)
    assert_equal 'chQ_' + choice_based_profile_question.id.to_s + '~0~!', get_link_to_filtered_mentors_list_for_choice_based(list_item)
  end

  def test_get_link_to_filtered_mentors_list_for_location_based
    list_location = locations(:chennai)
    list_profile_question = ProfileQuestion.first
    list_item = PreferenceBasedMentorList.new
    list_item.ref_obj = list_location
    list_item.profile_question = list_profile_question
    "search_filters_location_#{list_profile_question.id}_name" + "~" + list_location.full_city + '~!'
  end

  def test_get_applied_availabilty_filters_for_list
    user = users(:f_student)
    program = user.program
    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    program.stubs(:allow_non_match_connection?).returns(true)
    user.stubs(:can_send_mentor_request?).returns(true)
    self.stubs(:get_applied_availability_filter_params_for_list).with(UsersIndexFilters::Values::AVAILABLE).returns('available_filter#')
    assert_equal "available_filter#filter_show_no_match~show_no_match~!", get_applied_availabilty_filters_for_list(user, program)

    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    self.stubs(:get_applied_availability_filter_params_for_list).with(UsersIndexFilters::Values::CALENDAR_AVAILABILITY).returns('calendar_filter#')
    assert_equal "calendar_filter#filter_show_no_match~show_no_match~!", get_applied_availabilty_filters_for_list(user, program)
  end

  def test_get_applied_availability_filter_params_for_list
    self.stubs(:get_availablility_status_filter_fields).returns([{class: "availability_class", value: "applied_filter"}])
    assert_equal "filter_availability_class~applied_filter~!", get_applied_availability_filter_params_for_list("applied_filter")
  end

  def test_render_ignore_preference_based_mentor_list
    pbml = list_item = PreferenceBasedMentorList.new(ref_obj: locations(:chennai), profile_question_id: 'pqid', weight: 100)
    set_response_text render_ignore_preference_based_mentor_list(pbml)
    assert_select "div.btn-group" do
      assert_select "ul.dropdown-menu" do
        assert_select "a.cjs-ignore-preference-based-mentor-list-item", text: "Don't show this category again"
      end
    end
  end
end