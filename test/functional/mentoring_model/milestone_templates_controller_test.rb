require_relative './../../test_helper.rb'

class MentoringModel::MilestoneTemplatesControllerTest < ActionController::TestCase
  def setup
    super
    @program = programs(:albers)
    current_user_is :f_admin
    current_program_is @program
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @admin_role = @program.get_role(RoleConstants::ADMIN_NAME)
    @mentoring_model = @program.default_mentoring_model
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    @mentoring_model.should_sync = false
    @mentoring_model.save!
  end

  def test_permission_denied_disable_feature
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    assert_permission_denied do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_permission_denied_disable_permission
    @mentoring_model.deny_manage_mm_milestones!(@admin_role)
    @mentoring_model.reload

    assert_permission_denied do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_create_success
    @mentoring_model.mentoring_model_milestone_templates.destroy_all

    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_milestone_template: {title: "Claire Danes", description: "Carrie Mathison"}, :insert_milestone_after => nil, :milestone_position => nil}
    assert_response :success

    assert assigns(:milestone_template).present?
    assert_equal "Claire Danes", assigns(:milestone_template).title
    assert_equal "Carrie Mathison", assigns(:milestone_template).description
    assert_equal 0, assigns(:milestone_template).position
    assert_nil assigns(:previous_position_template_id)
    assert_nil assigns(:next_position_template_id)
  end

  def test_create_success_with_existing_milestones_present
    @mentoring_model.mentoring_model_milestone_templates.destroy_all

    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})

    assert_equal 1, mt2.position
    assert_equal 0, mt1.position

    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, mentoring_model_milestone_template: {title: "Claire Danes", description: "Carrie Mathison"}, :insert_milestone_after => "0", :milestone_position => MentoringModelsHelper::MilestonePosition::INSERT_AFTER.to_s}
    assert_response :success

    assert_equal 2, mt2.reload.position
    assert_equal 0, mt1.reload.position
    assert assigns(:milestone_template).present?
    assert_equal "Claire Danes", assigns(:milestone_template).title
    assert_equal "Carrie Mathison", assigns(:milestone_template).description
    assert_equal 1, assigns(:milestone_template).position
    assert_equal mt1.id, assigns(:previous_position_template_id)
    assert_equal mt2.id, assigns(:next_position_template_id)
  end

  def test_reorder_milestones
    @mentoring_model.mentoring_model_milestone_templates.destroy_all
    
    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})

    assert_equal 0, mt1.position
    assert_equal 1, mt2.position
    assert_equal 2, mt3.position

    MentoringModel.any_instance.expects(:increment_version_and_trigger_sync).once

    post :reorder_milestones, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, :new_milestone_order => [mt3.id.to_s, mt1.id.to_s, mt2.id.to_s]}

    assert_equal 1, mt1.reload.position
    assert_equal 2, mt2.reload.position
    assert_equal 0, mt3.reload.position
  end

  def test_validate_milestones_order
    @mentoring_model.mentoring_model_milestone_templates.destroy_all
    
    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})

    tt1 = create_mentoring_model_task_template
    tt2 = create_mentoring_model_task_template
    tt3 = create_mentoring_model_task_template

    tt1.update_attributes(:milestone_template_id => mt1.id, :required => true, :duration => 10)
    tt2.update_attributes(:milestone_template_id => mt2.id, :required => true, :duration => 20)
    tt3.update_attributes(:milestone_template_id => mt3.id, :required => true, :duration => 30)

    get :validate_milestones_order, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, :new_milestone_order => [mt1.id.to_s, mt3.id.to_s, mt2.id.to_s]}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response["show_warning"]
    assert_equal @mentoring_model.active_groups.size > 0, json_response["ongoing_connections_present"]
    assert assigns(:should_check_milestone_order)
    assert_equal [[mt1.position, 10, 10], [mt2.position, 20, 20], [mt3.position, 30, 30]], assigns(:current_first_and_last_required_task_in_milestones_list)

    mt3.update_attribute(:position, 1)
    mt2.update_attribute(:position, 2)

    get :validate_milestones_order, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, :new_milestone_order => [mt2.id.to_s, mt3.id.to_s, mt1.id.to_s]}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal false, json_response["show_warning"]
    assert_equal @mentoring_model.active_groups.size > 0, json_response["ongoing_connections_present"]
    assert_false assigns(:should_check_milestone_order)
    assert_equal [[mt1.position, 10, 10], [mt3.position, 30, 30], [mt2.position, 20, 20]], assigns(:current_first_and_last_required_task_in_milestones_list)
  end

  def test_update
    milestone_template = create_mentoring_model_milestone_template
    
    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: milestone_template.id, mentoring_model_milestone_template: {title: "Claire Danes", description: "Carrie Mathison"}}
    assert_response :success

    assert_equal "Claire Danes", assigns(:milestone_template).title
    assert_equal "Carrie Mathison", assigns(:milestone_template).description
    assert_equal({milestone_template.id => []}, assigns(:milestone_task_templates))
  end

  def test_destroy
    milestone_template = create_mentoring_model_milestone_template
    
    assert_difference "MentoringModel::MilestoneTemplate.count", -1 do
      delete :destroy, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: milestone_template.id}
      assert_response :success
    end    
  end

  def test_destroy_multiple_milestone_with_interlinked_task_templates
    mt1 = create_mentoring_model_milestone_template
    mt2 = create_mentoring_model_milestone_template

    tt1 = create_mentoring_model_task_template(milestone_template_id: mt1.id, required: true, duration: 1, associated_id: nil)
    tt2 = create_mentoring_model_task_template(milestone_template_id: mt1.id, required: true, duration: 2, associated_id: tt1.id)
    tt3 = create_mentoring_model_task_template(milestone_template_id: mt1.id, required: true, duration: 3, associated_id: tt2.id)

    tt4 = create_mentoring_model_task_template(milestone_template_id: mt2.id, required: true, duration: 5, associated_id: nil)
    tt5 = create_mentoring_model_task_template(milestone_template_id: mt2.id, required: true, duration: 6, associated_id: tt2.id)
    tt6 = create_mentoring_model_task_template(milestone_template_id: mt2.id, required: true, duration: 7, associated_id: tt5.id)
    
    assert_difference "MentoringModel::MilestoneTemplate.count", -1 do
      delete :destroy, xhr: true, params: { mentoring_model_id: mt1.mentoring_model.id, id: mt1.id}
      assert_response :success
    end
  end

  def test_new
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_template "new"
    assert assigns(:milestone_template).new_record?
    assert_no_select "h3.ct_milestone_summary"
  end

  def test_edit
    milestone_template = create_mentoring_model_milestone_template

    get :edit, xhr: true, params: { id: milestone_template.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal milestone_template, assigns(:milestone_template)
  end

  def test_new_for_program_with_disabled_ongoing_mentoring
    #disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end
end