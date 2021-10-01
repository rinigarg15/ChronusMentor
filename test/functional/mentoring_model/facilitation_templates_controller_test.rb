require_relative './../../test_helper.rb'

class MentoringModel::FacilitationTemplatesControllerTest < ActionController::TestCase
  def setup
    super
    current_user_is :f_admin
    @program = programs(:albers)
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentoring_model = @program.default_mentoring_model
    @admin_roles = @program.get_roles(RoleConstants::ADMIN_NAME)
    @user_roles = @program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    @mentoring_model.allow_manage_mm_messages!(@admin_roles)
  end

  def test_non_admin_permission_deny
    current_user_is :f_mentor
    assert_permission_denied do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_manage_mm_messages_at_admin_level_permission_deny
    @mentoring_model.deny_manage_mm_messages!(@admin_roles)
    assert_permission_denied do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_new
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    assert_equal @mentoring_model.id, assigns(:facilitation_template).mentoring_model_id
    assert_equal 7, assigns(:facilitation_template).send_on
    assert_nil assigns(:milestone_templates_to_associate)
  end

  def test_new_with_milestones_templates_to_associate
    @mentoring_model.allow_manage_mm_milestones!(@admin_roles)
    milestone = create_mentoring_model_milestone_template(mentoring_model_id: @mentoring_model.id)
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id, milestone_template_id: milestone.id}
    assert_equal 7, assigns(:facilitation_template).send_on
    assert_equal 1, assigns(:milestone_templates_to_associate).count
  end

  def test_new_with_milestone_template_assigned
    get :new, xhr: true, params: { milestone_template_id: 1, mentoring_model_id: @mentoring_model.id}
    assert_equal @mentoring_model.id, assigns(:facilitation_template).mentoring_model_id
    assert_equal 1, assigns(:facilitation_template).milestone_template_id
  end

  def test_new_with_survey_links_assigned
    facilitation_template = create_mentoring_model_facilitation_template
    survey_links = @program.surveys.of_engagement_type.map{|survey| {name: survey.name, value: "{{engagement_survey_link_#{survey.id}}}"}}
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
  end

  def test_create
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_facilitation_template: {message: "msg", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack", milestone_template_id: 7, date_assigner: MentoringModel::FacilitationTemplate::DueDateType::PREDECESSOR}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal "sub", facilitation_template.subject
    assert_equal "msg", facilitation_template.message
    assert_equal 10, facilitation_template.send_on
    assert_equal @program.get_roles(RoleConstants::MENTOR_NAME), facilitation_template.roles
    assert_equal @mentoring_model.id, facilitation_template.mentoring_model_id
    assert_not_equal 7, facilitation_template.milestone_template_id
  end

  def test_create_with_vulnerable_content_with_version_v1
    current_member_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_facilitation_template: {message: "msg<script>alert(10);</script>", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack", milestone_template_id: 7, date_assigner: MentoringModel::FacilitationTemplate::DueDateType::PREDECESSOR}}
    end
  end

  def test_create_with_vulnerable_content_with_version_v2
    current_member_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_facilitation_template: {message: "msg<script>alert(10);</script>", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack", milestone_template_id: 7, date_assigner: MentoringModel::FacilitationTemplate::DueDateType::PREDECESSOR}}
    end
  end

  def test_create_with_duration_id_input
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, duration_id_input: "7", mentoring_model_facilitation_template: {message: "msg", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack", milestone_template_id: 7, date_assigner: MentoringModel::FacilitationTemplate::DueDateType::PREDECESSOR}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal "sub", facilitation_template.subject
    assert_equal "msg", facilitation_template.message
    assert_equal 70, facilitation_template.send_on
    assert_equal @program.get_roles(RoleConstants::MENTOR_NAME), facilitation_template.roles
    assert_equal @mentoring_model.id, facilitation_template.mentoring_model_id
    assert_not_equal 7, facilitation_template.milestone_template_id
  end

  def test_with_specific_date
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, duration_id_input: "7", mentoring_model_facilitation_template: {message: "msg", subject: "sub", role_names: "mentor", program_id: "hack", milestone_template_id: 7, specific_date: '2012-12-28', date_assigner: MentoringModel::FacilitationTemplate::DueDateType::SPECIFIC_DATE}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal "sub", facilitation_template.subject
    assert_equal "msg", facilitation_template.message
    assert_nil facilitation_template.send_on
    assert_equal '2012-12-28', facilitation_template.specific_date.to_date.to_s
    assert_equal @program.get_roles(RoleConstants::MENTOR_NAME), facilitation_template.roles
    assert_equal @mentoring_model.id, facilitation_template.mentoring_model_id
    assert_not_equal 7, facilitation_template.milestone_template_id
  end

  def test_create_defaults
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_facilitation_template: {message: "Please enter mandatory details for this message here.", send_on: 7, role_names: "mentor", date_assigner: MentoringModel::FacilitationTemplate::DueDateType::PREDECESSOR}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal "Mentoring Insight", facilitation_template.subject
    assert_equal "Please enter mandatory details for this message here.", facilitation_template.message
    assert_equal 7, facilitation_template.send_on
    assert_equal @program.get_roles(RoleConstants::MENTOR_NAME), facilitation_template.roles
    assert_equal @mentoring_model, facilitation_template.mentoring_model
  end

  def test_create_with_milestone_enabled
    @mentoring_model.allow_manage_mm_milestones!(@admin_roles)
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_facilitation_template: {message: "msg", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack", milestone_template_id: 7, date_assigner: MentoringModel::FacilitationTemplate::DueDateType::PREDECESSOR}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal 7, facilitation_template.milestone_template_id
  end

  def test_edit
    facilitation_template = create_mentoring_model_facilitation_template
    get :edit, xhr: true, params: { id: facilitation_template.id, mentoring_model_id: @mentoring_model.id}
    assert_equal facilitation_template, assigns(:facilitation_template)
    assert_nil assigns(:milestone_templates_to_associate)
  end

  def test_edit_with_survey_links_assigned
    facilitation_template = create_mentoring_model_facilitation_template
    survey_links = @program.surveys.of_engagement_type.map{|survey| {name: survey.name, value: "{{engagement_survey_link_#{survey.id}}}"}}
    get :edit, xhr: true, params: { id: facilitation_template.id, mentoring_model_id: @mentoring_model.id}
    assert_equal survey_links.to_json, assigns(:survey_links)
  end

  def test_update
    facilitation_template = create_mentoring_model_facilitation_template
    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: facilitation_template.id, mentoring_model_facilitation_template: {message: "msg", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack"}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal "sub", facilitation_template.subject
    assert_equal "msg", facilitation_template.message
    assert_equal 10, facilitation_template.send_on
    assert_equal @program.get_roles(RoleConstants::MENTOR_NAME), facilitation_template.roles
    assert_equal @mentoring_model.id, facilitation_template.mentoring_model_id
  end

  def test_update_with_duration_id_input
    facilitation_template = create_mentoring_model_facilitation_template
    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, duration_id_input: 7, id: facilitation_template.id, mentoring_model_facilitation_template: {message: "msg", send_on: 10, subject: "sub", role_names: "mentor", program_id: "hack"}}
    facilitation_template = assigns(:facilitation_template)
    assert_equal "sub", facilitation_template.subject
    assert_equal "msg", facilitation_template.message
    assert_equal 70, facilitation_template.send_on
    assert_equal @program.get_roles(RoleConstants::MENTOR_NAME), facilitation_template.roles
    assert_equal @mentoring_model.id, facilitation_template.mentoring_model_id
  end


  def test_destroy
    facilitation_template = create_mentoring_model_facilitation_template
    delete :destroy, xhr: true, params: { id: facilitation_template.id, mentoring_model_id: @mentoring_model.id}
    assert_equal facilitation_template, assigns(:facilitation_template)
    assert MentoringModel::FacilitationTemplate.where(id: facilitation_template.id).empty?
  end

  def test_preview_email_success
    assert_emails do
      post :preview_email, xhr: true, params: { mentoring_model_id: @mentoring_model.id,mentoring_model_facilitation_template: {message: "Your facilitation message. program: {{program_name}} group: {{group_name}} user: {{user_name}}", subject: "Subject"}}
    end
    assert_response :success

    email = ActionMailer::Base.deliveries.last

    email_content = get_text_part_from(email)
    assert_equal "Subject - Smith and Doe", email.subject
    assert_equal users(:f_admin).email, email.to.first
    assert_match "Hi John", email_content
    assert_match "Thanks,\n\nAlbers Mentor Program", email_content
    assert_match /#{@program.name}/, email_content
    assert_match /Your facilitation message. program: Primary Organization group:\nSmith and Doe user: John Doe/, get_text_part_from(email)
    assert_equal AutoEmailNotification, assigns(:email)
  end
end