require_relative './../test_helper.rb'

class SectionsControllerTest < ActionController::TestCase

  def test_create
    current_user_is :f_admin
    SectionsController.any_instance.expects(:expire_cached_program_user_filters).once
    post :create, xhr: true, params: { :section => {:title => "Arbit Information", :description => "Some description"}}
    assert_equal assigns(:section).title, "Arbit Information"    
    assert_equal 7, assigns(:section).position
    assert_equal assigns(:section).description, "Some description"
  end

  def test_new_program
    current_user_is :f_admin
    get :new, xhr: true
    assert_equal programs(:org_primary), assigns(:section).organization    
  end

  def test_new_standalone
    Organization.any_instance.stubs(:programs_count).returns(1)
    current_user_is :f_admin
    get :new, xhr: true
    assert assigns(:current_organization).standalone?

    assert assigns(:section).new_record?
    assert_equal programs(:org_primary), assigns(:section).organization    
  end

  def test_update
    current_user_is :f_admin
    SectionsController.any_instance.expects(:expire_cached_program_user_filters).once
    put :update, xhr: true, params: { :id => sections(:section_albers).id, :section => {:title => "Arbit Information", :description => "Some description"}, :role => "mentor"}
    assert_equal assigns(:section), sections(:section_albers)
    assert_equal assigns(:section).title, "Arbit Information"
    assert_equal assigns(:section).description, "Some description"  
  end

  def test_update_student
    current_user_is :f_admin    
    put :update, xhr: true, params: { :id => sections(:section_albers).id, :section => { :title => "Arbit Information"}}
    assert_equal assigns(:section), sections(:section_albers)
    assert_equal assigns(:section).title, "Arbit Information"
  end

  def test_update_order
    current_user_is :f_admin
    section_ids = programs(:org_primary).sections.collect(&:id)
    new_order = [section_ids[0]] + section_ids[3..6] + section_ids[1..2]
    put :update, params: { :id => sections(:section_albers).id, :new_order => new_order    }
    assert_equal new_order, programs(:org_primary).sections.reload.collect(&:id)
  end

  
  def test_destroy
    current_user_is :f_admin
    SectionsController.any_instance.expects(:expire_cached_program_user_filters).once
    delete :destroy, xhr: true, params: { :id => sections(:section_albers).id}
    assert_equal assigns(:section), sections(:section_albers)    
  end

  def test_destroy_default_field
    current_user_is :f_admin
    assert_permission_denied do
      delete :destroy, xhr: true, params: { :id => sections(:sections_1).id}
    end
  end
end
