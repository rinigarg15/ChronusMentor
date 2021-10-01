require_relative './../../test_helper.rb'

class ThreeSixty::SurveysControllerTest < ActionController::TestCase

  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      get :new
    end

    assert_permission_denied do
      post :create
    end

    assert_permission_denied do
      get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      put :publish, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      put :update, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      get :dashboard
    end

    assert_permission_denied do
      put :reorder_competencies, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
  end

  def test_show_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary

    get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to new_session_path
  end

  def test_show_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_member_is :f_student

    assert_permission_denied do
      get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_nil assigns(:survey)
  end

  def test_show_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_false three_sixty_surveys(:survey_1).published?
    current_member_is :f_admin

    assert_permission_denied do
      get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_nil assigns(:survey_competencies)
    assert_nil assigns(:survey_oeqs)
    assert_nil assigns(:survey_assessees)
  end

  def test_show_not_belonging_to_program
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_nil assigns(:survey)
  end

  def test_show_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_user_is :ram

    get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    assert_equal three_sixty_surveys(:survey_1).survey_assessees.to_a, assigns(:survey_assessees).to_a
    assert assigns(:back_link).present?
  end

  def test_show_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_member_is :f_admin

    get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    assert_equal three_sixty_surveys(:survey_1).survey_assessees.to_a, assigns(:survey_assessees).to_a
    assert assigns(:back_link).present?
    assert_select "h3", :text => "Open-ended Questions", :count => 1

    three_sixty_surveys(:survey_1).survey_oeqs.destroy_all
    get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_equal [], assigns(:survey_oeqs)
    assert_select "h3", :text => "Open-ended Questions", :count => 0
  end

  def test_new_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :new
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :new
    end
  end

  def test_new_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :new
    assert_response :success

    assert_equal programs(:org_primary), assigns(:survey).organization
    assert_equal ThreeSixty::Survey::View::SETTINGS, assigns(:view)
    assert_false assigns(:survey_policy).present?
    assert assigns(:back_link).present?
  end

  def test_create_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    post :create
    assert_redirected_to new_session_path
  end

  def test_create_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :create
    end
  end

  def test_create_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    assert_no_difference "ThreeSixty::Survey.count" do
      post :create, params: { :three_sixty_survey => {:expiry_date => Time.zone.now + 3.days}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    end
    assert_response :success
    assert_equal programs(:org_primary), assigns(:survey).organization
    assert_nil assigns(:survey).title
    assert_false assigns(:survey).valid?
    assert_equal "Please fix the highlighted errors.", flash[:error]

    assert_no_difference "ThreeSixty::Survey.count" do
      post :create, params: { :three_sixty_survey => {:title => "new title", :expiry_date => Time.zone.now - 3.days}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    end
    assert_equal ["can't be in the past"], assigns(:survey).errors[:expiry_date]
    assert_response :success
    assert_false assigns(:survey).valid?
    assert_equal ThreeSixty::Survey::View::SETTINGS, assigns(:view)
    assert_equal "Please fix the highlighted errors.", flash[:error]
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    time = Time.zone.now + 3.days
    assert_difference "ThreeSixty::Survey.count", 1 do
      post :create, params: { :three_sixty_survey => {:title => "new title", :expiry_date => time}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    end
    assert_redirected_to add_questions_three_sixty_survey_path(assigns(:survey))
    assert_equal programs(:org_primary), assigns(:survey).organization
    assert_equal "new title", assigns(:survey).title
    assert_equal time.utc.to_date, assigns(:survey).expiry_date
    assert_false assigns(:survey_policy).present?
    assert_equal "The survey has been successfully created. Please choose the competencies and questions you want for the survey.", flash[:notice]
  end

  def test_create_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram
    assert_difference "ThreeSixty::Survey.count", 1 do
      post :create, params: { :three_sixty_survey => {:title => "new title"}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    end
    assert_redirected_to add_questions_three_sixty_survey_path(assigns(:survey))
    assert_equal programs(:org_primary), assigns(:survey).organization
    assert_equal programs(:albers), assigns(:survey).program
    assert_equal "new title", assigns(:survey).title
    assert_false assigns(:survey_policy).present?
    assert_equal "The survey has been successfully created. Please choose the competencies and questions you want for the survey.", flash[:notice]
  end

  def test_dashboard_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :dashboard
    assert_redirected_to new_session_path
  end

  def test_dashboard_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :dashboard
    end
  end

  def test_dashboard_success
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [1, 2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [1, 2, 3]).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "published", id: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, includes_list: [{survey: [:program]}, :assessee, {reviewers: :answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13, 14]).paginate(page: 1, per_page: 5).includes([{survey: [:program]}, :assessee, {reviewers: :answers}])).once

    org = programs(:org_primary)
    org.enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :dashboard
    assert_equal ThreeSixty::CommonController::Tab::SURVEYS, assigns(:active_tab)
    assert_equal org.published_three_sixty_survey_assessees.to_a.sort_by!{|sa| sa.survey.title.mb_chars.downcase}[0,5], assigns(:survey_assessees).to_a
    assert_equal org.three_sixty_surveys.drafted.to_a, assigns(:surveys).to_a

    assessee = three_sixty_surveys(:survey_4).survey_assessees.first
    answered_reviewers_count = assessee.reviewers.select{ |r| r.answered? }.size
    assessee.reviewers.create!(:name => 'some name', :email => "someemail@example.com", :three_sixty_survey_reviewer_group_id => assessee.survey.survey_reviewer_groups.last.id)

    survey = org.reload.three_sixty_surveys.drafted.first

    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [1, 2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [1, 2, 3]).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "published", id: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, includes_list: [{survey: [:program]}, :assessee, {reviewers: :answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13, 14]).includes([{survey: [:program]}, :assessee, {reviewers: :answers}]).paginate(page: 1, per_page: 5)).once

    get :dashboard

    assert_select "table" do
      assert_select "thead" do
        assert_select "tr" do
          assert_select "th", :text => "Assessee"
          assert_select "th", :text => "Survey"
          assert_select "th", :text => "Issued"
          assert_select "th", :text => "Expires"
          assert_select "th", :text => "Responses"
        end
      end
      assert_select "tbody" do
        assert_select "tr" do
          assert_select "td", :text => assessee.assessee.name(:name_only => true)
          assert_select "td", :text => assessee.survey.title
          assert_select "td", :text => assessee.survey.created_at.strftime("%B %d, %Y")
          assert_select "td", :text => assessee.survey.expiry_date.strftime("%B %d, %Y")
          assert_select "td", :text => "#{answered_reviewers_count}/#{assessee.reviewers.size}"
        end
      end
    end

    assert_select "table#drafted_surveys_table" do
      assert_select "thead" do
        assert_select "tr" do
          assert_select "th", :text => "Survey"
          assert_select "th", :text => "Assessees"
          assert_select "th", :text => "Created"
        end
      end
      assert_select "tbody" do
        assert_select "tr" do
          assert_select "td", :text => /#{survey.title}/ do
            assert_select "div.text-muted", :text => survey.program.name
          end
          assert_select "td", :text => survey.created_at.strftime("%B %d, %Y")
        end
      end
    end
  end

  def test_dashboard_with_no_conditions
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [1, 2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [1, 2, 3]).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "published", id: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, includes_list: [{survey: [:program]}, :assessee, {reviewers: :answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13, 14]).includes([{survey: [:program]}, :assessee, {reviewers: :answers}]).paginate(page: 1, per_page: 5)).once
    org = programs(:org_primary)
    org.enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    get :dashboard
    assert_response :success
    survey_assessees = [three_sixty_survey_assessees(:three_sixty_survey_assessees_10), three_sixty_survey_assessees(:three_sixty_survey_assessees_11), three_sixty_survey_assessees(:three_sixty_survey_assessees_12), three_sixty_survey_assessees(:three_sixty_survey_assessees_13), three_sixty_survey_assessees(:three_sixty_survey_assessees_14)]
    assert_equal survey_assessees, assigns(:survey_assessees).to_a
    surveys = [three_sixty_surveys(:survey_1), three_sixty_surveys(:survey_2), three_sixty_surveys(:survey_3)]
    assert_equal surveys, assigns(:surveys).to_a
  end

  def test_dashboard_with_surveys
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [1, 2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [1, 2, 3]).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "published", id: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, includes_list: [{survey: [:program]}, :assessee, {reviewers: :answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13, 14]).includes([{survey: [:program]}, :assessee, {reviewers: :answers}]).paginate(page: 1, per_page: 5)).once
    org = programs(:org_primary)
    org.enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :dashboard
    assert_response :success
    survey_assessees = [three_sixty_survey_assessees(:three_sixty_survey_assessees_10), three_sixty_survey_assessees(:three_sixty_survey_assessees_11), three_sixty_survey_assessees(:three_sixty_survey_assessees_12), three_sixty_survey_assessees(:three_sixty_survey_assessees_13), three_sixty_survey_assessees(:three_sixty_survey_assessees_14)]
    assert_equal survey_assessees, assigns(:survey_assessees).to_a
  end

  def test_dashboard_with_survey_assessees
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [1, 2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [1, 2, 3]).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "published", id: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, includes_list: [{survey: [:program]}, :assessee, {reviewers: :answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13, 14]).includes([{survey: [:program]}, :assessee, {reviewers: :answers}]).paginate(page: 1, per_page: 5)).once
    org = programs(:org_primary)
    org.enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :dashboard
    assert_response :success
    surveys = [three_sixty_surveys(:survey_1), three_sixty_surveys(:survey_2), three_sixty_surveys(:survey_3)]
    assert_equal surveys, assigns(:surveys).to_a
  end

  def test_dashboard_with_no_surveys
    program = programs(:foster)
    organization = programs(:org_foster)
    organization.enable_feature(FeatureName::THREE_SIXTY)

    ThreeSixty::Survey.expects(:get_es_results).with( { sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: { page: 1, per_page: 5, sort_field: "title", sort_order: "asc" }, filter: { organization_id: organization.id, state: "drafted", program_id: program.id, id: [0] }, includes_list: [:program, :survey_questions, :survey_reviewer_groups, { survey_assessees: :assessee } ] } ).returns(ThreeSixty::Survey.where(id: [0]).includes([:program, :survey_questions, :survey_reviewer_groups, { survey_assessees: :assessee } ]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with( { sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: { page: 1, per_page: 5, sort_field: "title", sort_order: "asc" }, filter: { organization_id: organization.id, state: "published", program_id: program.id, id: [0] }, includes_list: [ { survey: [:program] }, :assessee, { reviewers: :answers } ] } ).returns(ThreeSixty::SurveyAssessee.where(id: [0]).includes([ { survey: [:program] }, :assessee, { reviewers: :answers } ]).paginate(page: 1, per_page: 5)).once
    current_member_is :foster_admin
    get :dashboard
    assert_response :success
    assert_empty assigns(:surveys).to_a
  end

  def test_dashboard_with_no_survey_assessees
    program = programs(:foster)
    organization = programs(:org_foster)
    organization.enable_feature(FeatureName::THREE_SIXTY)

    ThreeSixty::Survey.expects(:get_es_results).with( { sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: { page: 1, per_page: 5, sort_field: "title", sort_order: "asc" }, filter: { organization_id: organization.id, state: "drafted", program_id: program.id, id: [0] }, includes_list: [:program, :survey_questions, :survey_reviewer_groups, { survey_assessees: :assessee } ] } ).returns(ThreeSixty::Survey.where(id: [0]).paginate(page: 1, per_page: 5)).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with( { sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: { page: 1, per_page: 5, sort_field: "title", sort_order: "asc" }, filter: { organization_id: organization.id, state: "published", program_id: program.id, id: [0] }, includes_list: [ { survey: [:program] }, :assessee, { reviewers: :answers } ] } ).returns(ThreeSixty::SurveyAssessee.where(id: [0]).includes([ { survey: [:program] }, :assessee, { reviewers: :answers } ]).paginate(page: 1, per_page: 5)).once
    current_member_is :foster_admin
    get :dashboard
    assert_response :success
    assert_empty assigns(:survey_assessees).to_a
  end

  def test_edit_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to new_session_path
  end

  def test_edit_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    end
  end

  def test_edit_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_edit_not_belonging_to_program
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(false)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      get :show, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_nil assigns(:survey)
  end

  def test_edit_success_program_level
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(false)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_user_is :ram

    get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal ThreeSixty::Survey::View::SETTINGS, assigns(:view)
    assert assigns(:survey_policy).present?
  end

  def test_edit_success
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(false)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal ThreeSixty::Survey::View::SETTINGS, assigns(:view)
    assert assigns(:survey_policy).present?
  end

  def test_edit_add_reviewers_by
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(false)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    three_sixty_surveys(:survey_1).update_attributes(:reviewers_addition_type => ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    get :edit, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success
    assert_match(/disabled/, @response.body)
    assert_select "form.cjs_three_sixty_survey_form" do
      assert_select "label[title='There are existing reviewers added by the admin. Please discard the reviewers before selecting this option.']"
      assert_select "input[disabled=disabled]"
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
  end

  def test_update_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the title"}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    assert_redirected_to new_session_path
  end

  def test_update_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the  title"}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    end
  end

  def test_update_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the title", :expiry_date => Time.zone.now - 3.days}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    assert_equal ["can't be in the past"], assigns(:survey).errors[:expiry_date]
    assert_response :success
    assert_false assigns(:survey).valid?
    assert_equal ThreeSixty::Survey::View::SETTINGS, assigns(:view)
    assert_equal "Please fix the highlighted errors.", flash[:error]
    assert_false three_sixty_surveys(:survey_1).reload.title == "updating the title"
    assert_equal ThreeSixty::Survey::View::SETTINGS, assigns(:view)
  end

  def test_update_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    time = Time.zone.now + 3.days

    put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the title", :expiry_date => time}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_update_not_belonging_to_program
    time = Time.zone.now + 3.days
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the title", :expiry_date => time}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    end

    assert_nil assigns(:survey)
  end

  def test_update_success_program_level
    time = Time.zone.now + 3.days
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the title", :expiry_date => time}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    assert_redirected_to add_questions_three_sixty_survey_path(assigns(:survey))
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal "updating the title", three_sixty_surveys(:survey_1).reload.title
    assert_equal time.utc.to_date, three_sixty_surveys(:survey_1).expiry_date
    assert assigns(:survey_policy).present?
    assert_equal "The survey has been successfully updated.", flash[:notice]
  end

  def test_update_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    time = Time.zone.now + 3.days

    put :update, params: { :id => three_sixty_surveys(:survey_1).id, :three_sixty_survey => {:title => "updating the title", :expiry_date => time}, :survey_reviewer_groups => programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type.pluck(:id)}
    assert_redirected_to add_questions_three_sixty_survey_path(assigns(:survey))
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal "updating the title", three_sixty_surveys(:survey_1).reload.title
    assert_equal time.utc.to_date, three_sixty_surveys(:survey_1).expiry_date
    assert assigns(:survey_policy).present?
    assert_equal "The survey has been successfully updated.", flash[:notice]
  end

  def test_add_questions_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to new_session_path
  end

  def test_add_questions_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    end
  end

  def test_add_questions_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_add_questions_redirect_to_survey_edit_if_settings_error
    ThreeSixty::SurveyPolicy.any_instance.stubs(:settings_error?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to edit_three_sixty_survey_path(three_sixty_surveys(:survey_1))
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_add_questions_not_belonging_to_program
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_nil assigns(:survey)
  end

  def test_add_questions_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal_unordered [three_sixty_competencies(:leadership), three_sixty_competencies(:delegating)], assigns(:available_competencies)
    assert three_sixty_competencies(:decision_making).questions.empty?
    assert_equal ThreeSixty::Survey::View::QUESTIONS, assigns(:view)
    assert assigns(:survey_policy).present?
    assert_equal 2, assigns(:survey_oeqs).size
    assert_equal [three_sixty_questions(:oeq_3)], assigns(:available_oeqs)
  end

  def test_add_questions_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_questions, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    assert_equal_unordered [three_sixty_competencies(:leadership), three_sixty_competencies(:delegating)], assigns(:available_competencies)
    assert three_sixty_competencies(:decision_making).questions.empty?
    assert_equal ThreeSixty::Survey::View::QUESTIONS, assigns(:view)
    assert assigns(:survey_policy).present?
    assert assigns(:back_link).present?
  end

  def test_preview_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to new_session_path
  end

  def test_preview_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    end
  end

  def test_preview_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_preview_redirect_to_survey_edit_if_settings_error
    ThreeSixty::SurveyPolicy.any_instance.stubs(:settings_error?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to edit_three_sixty_survey_path(three_sixty_surveys(:survey_1))
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_preview_redirect_to_redirect_to_survey_questions_if_questions_error
    ThreeSixty::SurveyPolicy.any_instance.stubs(:questions_error?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to add_questions_three_sixty_survey_path(three_sixty_surveys(:survey_1))
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_preview_not_belonging_to_program
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_nil assigns(:survey)
  end

  def test_preview_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal ThreeSixty::Survey::View::PREVIEW, assigns(:view)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    assert assigns(:survey_policy).present?
  end

  def test_preview_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal ThreeSixty::Survey::View::PREVIEW, assigns(:view)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    assert assigns(:survey_policy).present?
    assert assigns(:back_link).present?
    assert_select "h3", :text => "Open-ended Questions", :count => 1

    three_sixty_surveys(:survey_1).survey_oeqs.destroy_all
    get :preview, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_equal [], assigns(:survey_oeqs)
    assert_select "h3", :text => "Open-ended Questions", :count => 0
  end

  def test_add_assessees_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to new_session_path
  end

  def test_add_assessees_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    end
  end

  def test_add_assessees_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_add_assessees_redirect_to_survey_edit_if_settings_error
    ThreeSixty::SurveyPolicy.any_instance.stubs(:settings_error?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to edit_three_sixty_survey_path(three_sixty_surveys(:survey_1))
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_add_assessees_redirect_to_redirect_to_survey_questions_if_questions_error
    ThreeSixty::SurveyPolicy.any_instance.stubs(:questions_error?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_redirected_to add_questions_three_sixty_survey_path(three_sixty_surveys(:survey_1))
    assert_equal "Text for test", flash[:error]
    assert assigns(:survey_policy).present?
  end

  def test_add_assessees_not_belonging_to_program
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_nil assigns(:survey)
  end

  def test_add_assessees_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal ThreeSixty::Survey::View::ASSESSEES, assigns(:view)
    assert_equal three_sixty_surveys(:survey_1).survey_assessees.to_a, assigns(:survey_assessees).to_a
    assert assigns(:survey_policy).present?
  end

  def test_add_assessees_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :add_assessees, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_response :success

    assert_equal ThreeSixty::Survey::View::ASSESSEES, assigns(:view)
    assert_equal three_sixty_surveys(:survey_1).survey_assessees.to_a, assigns(:survey_assessees).to_a
    assert assigns(:survey_policy).present?
    assert assigns(:back_link).present?
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::Survey.count" do
      delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
  end

  def test_destroy_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_no_difference "ThreeSixty::Survey.count" do
      assert_permission_denied do
        delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
      end
    end
  end

  def test_destroy_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_difference "ThreeSixty::Survey.count" do
      delete :destroy, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]

    assert_no_difference "ThreeSixty::Survey.count" do
      delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_template "three_sixty/surveys/_policy_warning"
    assert assigns(:survey_policy).present?
  end

  def test_destroy_not_belonging_to_program
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      assert_no_difference "ThreeSixty::Survey.count" do
        delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
      end
    end

    assert_nil assigns(:survey)
  end

  def test_destroy_success_program_level
    program = programs(:albers)
    organization = program.organization
    organization.enable_feature(FeatureName::THREE_SIXTY)

    current_user_is :ram
    ThreeSixty::Survey.expects(:get_es_results).with( { sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: { page: 1, per_page: 5, sort_field: "title", sort_order: "asc" }, filter: { organization_id: organization.id, state: "drafted", program_id: program.id, id: [2] }, includes_list: [:program, :survey_questions, :survey_reviewer_groups, { survey_assessees: :assessee } ] }).returns(ThreeSixty::Survey.where(id: [2]).includes([:program, :survey_questions, :survey_reviewer_groups, { survey_assessees: :assessee } ]).paginate(page: 1, per_page: 5)).once

    assert_difference "ThreeSixty::Survey.count", -1 do
      delete :destroy, xhr: true, params: { id: three_sixty_surveys(:survey_1).id }
    end
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert assigns(:survey_policy).present?
    assert_response :success

    assert_difference "ThreeSixty::Survey.count", -1 do
      delete :destroy, params: { id: three_sixty_surveys(:survey_2).id }
    end
    assert_equal three_sixty_surveys(:survey_2), assigns(:survey)
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert assigns(:survey_policy).present?
  end

  def test_destroy_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    ThreeSixty::Survey.expects(:get_es_results).with({:sort_param=>"title", :sort_order=>"asc", :page=>1, :per_page=>5, :search_params=>{:page=>1, :per_page=>5, :sort_field=>"title", :sort_order=>"asc"}, :filter=>{:organization_id=>1, :state=>"drafted", :id=>[2, 3, 4, 5]}, :includes_list=>[:program, :survey_questions, :survey_reviewer_groups, {:survey_assessees=>:assessee}]}).returns(ThreeSixty::Survey.where(id: [2, 3]).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]).paginate(page: 1, per_page: 5)).once
    assert_difference "ThreeSixty::Survey.count", -1 do
      delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_response :success

    assert_difference "ThreeSixty::Survey.count", -1 do
      delete :destroy, params: { :id => three_sixty_surveys(:survey_2).id}
    end
    assert_equal three_sixty_surveys(:survey_2), assigns(:survey)
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert assigns(:survey_policy).present?
  end

  def test_destroy_set_drafted_surveys
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 2, per_page: 5, search_params: {page: 2, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: []).paginate(page: 2, per_page: 5).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}])).once
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [2, 3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [2, 3]).paginate(page: 1, per_page: 5).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}])).once
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    assert_difference "ThreeSixty::Survey.count", -1 do
      delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id, :page => "2"}
    end
    assert_equal ThreeSixty::Survey.where(:state => "drafted").to_a, assigns(:surveys).to_a
    assert_equal 1, assigns(:options)[:page]
    ThreeSixty::Survey.expects(:get_es_results).with({sort_param: "title", sort_order: "asc", page: 1, per_page: 5, search_params: {page: 1, per_page: 5, sort_field: "title", sort_order: "asc"}, filter: {organization_id: 1, state: "drafted", id: [3, 4, 5]}, includes_list: [:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}]}).returns(ThreeSixty::Survey.where(id: [3]).paginate(page: 1, per_page: 5).includes([:program, :survey_questions, :survey_reviewer_groups, {survey_assessees: :assessee}])).once
    assert_difference "ThreeSixty::Survey.count", -1 do
      delete :destroy, xhr: true, params: { :id => three_sixty_surveys(:survey_2).id, :page => "1"}
    end
    assert_equal 1, assigns(:options)[:page]
  end

  def test_publish_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    assert three_sixty_surveys(:survey_1).may_publish?

    put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    assert_false three_sixty_surveys(:survey_1).reload.published?
  end

  def test_publish_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student
    assert three_sixty_surveys(:survey_1).may_publish?

    assert_permission_denied do
      put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert_false three_sixty_surveys(:survey_1).reload.published?
  end

  def test_publish_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_emails do
      put :publish, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]
    assert three_sixty_surveys(:survey_1).reload.drafted?

    assert_no_emails do
      put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end

    assert_template "three_sixty/surveys/_policy_warning"
    assert three_sixty_surveys(:survey_1).reload.drafted?
    assert assigns(:survey_policy).present?
  end

  def test_publish_failure
    ThreeSixty::SurveyAssessee.destroy_all
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    assert_false three_sixty_surveys(:survey_1).may_publish?

    assert_no_emails do
      put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert_false three_sixty_surveys(:survey_1).reload.published?
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)

    assert_no_emails do
      put :publish, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert_redirected_to add_assessees_three_sixty_survey_path(three_sixty_surveys(:survey_1))
    assert_false three_sixty_surveys(:survey_1).reload.published?
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert assigns(:survey_policy).present?
  end

  def test_publish_not_belonging_to_program
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      assert_no_emails do
        put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
      end
    end

    assert_nil assigns(:survey)
  end

  def test_publish_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    assert three_sixty_surveys(:survey_1).may_publish?

    assert_emails 3 do
      put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert three_sixty_surveys(:survey_1).reload.published?
  end

  def test_publish_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    assert three_sixty_surveys(:survey_1).may_publish?
    assert three_sixty_surveys(:survey_3).may_publish?

    assert_emails 3 do
      put :publish, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id}
    end
    assert three_sixty_surveys(:survey_1).reload.published?

    assert_emails 2 do
      put :publish, params: { :id => three_sixty_surveys(:survey_3).id}
    end
    assert three_sixty_surveys(:survey_3).reload.published?
    assert assigns(:survey_policy).present?
    assert_equal "The survey 'Survey For Level 3 Employees' has been successfully published and the assessees have been notified.", flash[:notice]
    assert_redirected_to three_sixty_survey_path(three_sixty_surveys(:survey_3))

    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_equal "#{three_sixty_surveys(:survey_3).title}: Invitation to self-assess", email.subject
    assert_match "As part of your 360 degree feedback review, you are requested to complete a self-assessment. The questions in the self-assessment will be the same as those posed to your reviewers.", mail_content
    assert_match "Complete the survey", mail_content
    assert_match "/reviewers/show_reviewers", mail_content
  end

  def test_reorder_competencies_not_logged_in
    ReorderService.any_instance.stubs(:reorder).at_most(0)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    put :reorder_competencies, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id, "new_order"=>["2", "1"]}
  end

  def test_reorder_competencies_non_admin_permission_denied
    ReorderService.any_instance.stubs(:reorder).at_most(0)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      put :reorder_competencies, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id, "new_order"=>["2", "1"]}
    end
  end

  def test_reorder_competencies_redirect_unless_survey_is_editable
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_editable?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    ReorderService.any_instance.stubs(:reorder).at_most(0)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    put :reorder_competencies, params: { :id => three_sixty_surveys(:survey_1).id, "new_order"=>["2", "1"]}

    assert_redirected_to dashboard_three_sixty_surveys_path
    assert_equal "Text for test", flash[:error]

    put :reorder_competencies, xhr: true, params: { :id => three_sixty_surveys(:survey_1).id, "new_order"=>["2", "1"]}

    assert_template "three_sixty/surveys/_policy_warning"
    assert assigns(:survey_policy).present?
  end

  def test_reorder_competencies_failure
    ReorderService.any_instance.stubs(:reorder).with(["2", "1", "Some thing that causes a failure"]).at_least(1)

    survey = three_sixty_surveys(:survey_1)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    put :reorder_competencies, xhr: true, params: { :id => survey.id, "new_order"=>["2", "1", "Some thing that causes a failure"]}
  end

  def test_reorder_competencies_not_belonging_to_program
    ReorderService.any_instance.stubs(:reorder).with(["2", "1"]).at_most(0)
    survey = three_sixty_surveys(:survey_1)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :nwen_admin

    assert_raise(ActiveRecord::RecordNotFound) do
      put :reorder_competencies, xhr: true, params: { :id => survey.id, "new_order"=>["2", "1"]}
    end

    assert_nil assigns(:survey)
  end

  def test_reorder_competencies_success_program_level
    ReorderService.any_instance.stubs(:reorder).with(["2", "1"]).at_least(1)
    survey = three_sixty_surveys(:survey_1)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    put :reorder_competencies, xhr: true, params: { :id => survey.id, "new_order"=>["2", "1"]}
  end

  def test_reorder_competencies_success
    ReorderService.any_instance.stubs(:reorder).with(["2", "1"]).at_least(1)
    survey = three_sixty_surveys(:survey_1)

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    put :reorder_competencies, xhr: true, params: { :id => survey.id, "new_order"=>["2", "1"]}
  end
end
