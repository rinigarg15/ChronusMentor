require_relative "./../../test_helper.rb"
require_relative "./../../../app/helpers/programs_helper"

class MentorRequestsHelperTest < ActionView::TestCase
  include TranslationsService
  include ProgramsHelper

  def test_render_exp
    assert_equal "Lead Developer, Microsoft", render_exp(members(:f_mentor))
    assert_equal "", render_exp(members(:f_admin))
  end

  def test_suggested_user
    rahim = users(:rahim)
    
    mentor1 = users(:f_mentor)
    mentor2 = users(:f_mentor_student)
    favorite_mentors = [mentor1, mentor2]

    favorites = []
    #creating user favorites
    fav1 = UserFavorite.new
    fav1.user = rahim
    fav1.favorite = mentor1
    fav1.position = 1
    fav1.save!

    fav2 = UserFavorite.new
    fav2.user = rahim
    fav2.favorite = mentor2
    fav2.position = 1
    fav2.save!

    favorites << fav1
    favorites << fav2

    recommended_users = rahim.mentor_recommendation.recommended_users

    assert_equal_unordered [], suggested_users(nil, nil).values
    assert_equal_unordered favorite_mentors, suggested_users(favorites, nil).values
    assert_equal_unordered recommended_users, suggested_users(nil, recommended_users).values
    assert_equal_unordered favorite_mentors | recommended_users, suggested_users(favorites, recommended_users).values
  end

  def test_dropdown_cell_recommendation
    rahim = users(:rahim)
    ram = users(:ram)
    @current_user = rahim
    @current_program = rahim.program
    match_array = rahim.student_cache_normalized
    return_value = dropdown_cell_recommendation(ram, match_array: match_array)
    set_response_text(return_value)
    assert_select "li#dropdown-#{ram.id}.cjs_mentor_result.hide", 0
    assert_select "li#dropdown-#{ram.id}.cjs_mentor_result" do
      assert_select "h3", text: ram.name(name_only: true)
    end
  end

  def test_dropdown_cell_recommendation_already_recommended_user
    rahim = users(:rahim)
    ram = users(:ram)
    @current_user = rahim
    @current_program = rahim.program
    recommended_users = rahim.mentor_recommendation.recommended_users
    match_array = rahim.student_cache_normalized
    return_value = dropdown_cell_recommendation(ram, match_array: match_array, mentor_users: recommended_users)
    set_response_text(return_value)
    assert_select "li#dropdown-#{ram.id}.cjs_mentor_result.hide" do
      assert_select "h3", text: ram.name(name_only: true)
    end
  end

  def test_get_tabs_for_mentor_requests_listing
    @current_program = programs(:albers)
    Program.any_instance.stubs(:allow_mentee_withdraw_mentor_request?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    active_tab = MentorRequest::Filter::ACTIVE
    label_tab_mapping = {
      "Pending" => MentorRequest::Filter::ACTIVE,
      "Accepted" => MentorRequest::Filter::ACCEPTED,
      "Rejected" => MentorRequest::Filter::REJECTED,
    }
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: manage_mentor_requests_path, param_name: :tab)
    get_tabs_for_mentor_requests_listing(active_tab)
    Program.any_instance.stubs(:allow_mentee_withdraw_mentor_request?).returns(true)
    label_tab_mapping.merge!("Withdrawn" => MentorRequest::Filter::WITHDRAWN)
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: manage_mentor_requests_path, param_name: :tab)
    get_tabs_for_mentor_requests_listing(active_tab)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(true)
    label_tab_mapping.merge!("Closed" => MentorRequest::Filter::CLOSED)
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: manage_mentor_requests_path, param_name: :tab)
    get_tabs_for_mentor_requests_listing(active_tab)
  end

  def test_render_meeting_recommendation
    mentor_request = mentor_requests(:mentor_request_0)

    MentorRequest.any_instance.stubs(:can_convert_to_meeting_request?).returns(false)

    self.expects(:render).never
    render_meeting_recommendation("", "", mentor_request, "")

    MentorRequest.any_instance.stubs(:can_convert_to_meeting_request?).returns(true)
    self.expects(:render).with(partial: "mentor_requests/recommend_meeting", locals: { form: "", form_id: "", mentor_request: mentor_request, modal_id: "" })
    render_meeting_recommendation("", "", mentor_request, "")
  end

  def test_user_name_search_filter_for_mentor_request
    html_content = to_html(user_name_search_filter_for_mentor_request("title", "field_name"))
    assert_select html_content, "div.ibox" do
      assert_select "div.ibox-title" do
        assert_select "div.ibox-title-content" do
          assert_select "b", text: "title"
        end
      end
      assert_select "div.ibox-content" do
        assert_select "label.sr-only", text: "title"
        assert_select "input#search_filters_field_name[type=text][name='search_filters[field_name]']"
      end
    end
  end

  def test_mentor_request_reject_reasons
    program = programs(:albers)
    program.stubs(:allow_mentee_withdraw_mentor_request?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_equal ['feature.mentor_request.status.Rejected'.translate, 'feature.mentor_request.status.Withdrawn'.translate], mentor_request_reject_reasons(program)

    program.stubs(:allow_mentee_withdraw_mentor_request?).returns(false)
    assert_equal ['feature.mentor_request.status.Rejected'.translate], mentor_request_reject_reasons(program)

    program.stubs(:matching_by_mentee_alone?).returns(true)
    assert_equal ['feature.mentor_request.status.Rejected'.translate, 'feature.mentor_request.status.closed'.translate], mentor_request_reject_reasons(program)

    program.stubs(:allow_mentee_withdraw_mentor_request?).returns(true)
    assert_equal ['feature.mentor_request.status.Rejected'.translate, 'feature.mentor_request.status.Withdrawn'.translate, 'feature.mentor_request.status.closed'.translate], mentor_request_reject_reasons(program)
  end

  def test_get_mentor_requests_export_options
    program = programs(:albers)
    assert_empty get_mentor_requests_export_options(program)
    Program.any_instance.stubs(:matching_by_mentee_and_admin?).returns(true)
    assert_equal [{ label: "feature.membership_request.label.export_as_csv".translate, class: "cjs-common-reports-export-ajax", url: manage_mentor_requests_path(export: :csv) },{ label: "feature.membership_request.label.export_as_pdf".translate, class: "cjs-common-reports-export-ajax", url: manage_mentor_requests_path(export: :pdf) }], get_mentor_requests_export_options(program)
  end
end