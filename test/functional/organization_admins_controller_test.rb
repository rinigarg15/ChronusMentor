require_relative './../test_helper.rb'

class OrganizationAdminsControllerTest < ActionController::TestCase
  def test_index_for_admin
    current_member_is :f_admin

    get :index
    assert_response :success
    assert_match UserPromotedToAdminNotification.mailer_attributes[:uid], response.body
    assert_equal [members(:f_admin)], assigns(:admins)
  end

  def test_index_not_for_non_admins
    current_member_is :f_mentor

    assert_permission_denied do
      get :index
    end
  end

  def update_custom_term_for_admin(member)
    admin_custom_term_id = member.programs.first.organization.customized_terms.includes(:translations).where(term_type: "Admin").first.id
  	CustomizedTerm.find_by(id: admin_custom_term_id).update_attributes(term: "Facilitator", term_downcase: "facilitator", pluralized_term: "Facilitators", pluralized_term_downcase: "facilitators", articleized_term: "a Facilitator", articleized_term_downcase: "a facilitator")
  end

  def test_create_admin_success
    current_member_is :f_admin
    assert_false members(:student_1).admin?
    student = members(:student_1)
    admin = members(:f_admin)
    UserPromotedToAdminNotification.expects(:user_promoted_to_admin_notification).with(student, admin).once.returns(stub(:deliver_now))
    update_custom_term_for_admin(student)
    post :create, params: { :member => {:name_with_email => members(:student_1).name_with_email}}
    assert_redirected_to organization_admins_path
    assert_equal "#{members(:student_1).name(:name_only => true)} has been added to the list of facilitators", flash[:notice]
    assert members(:student_1).reload.admin?
  end

  def test_create_existing_admin
    current_member_is :f_admin
    admin = members(:f_admin)
    update_custom_term_for_admin(admin)
    post :create, params: { :member => {:name_with_email => members(:f_admin).name_with_email}}
    assert_redirected_to organization_admins_path
    assert_equal "#{members(:f_admin).name(:name_only => true)} has been added to the list of facilitators", flash[:notice]
  end

  def test_create_existing_dormant_user_as_admin
    current_member_is :no_subdomain_admin
    member = members(:no_subdomain_admin)
    update_custom_term_for_admin(member)
    post :create, params: { :member => {:name_with_email => members(:dormant_member).name_with_email}}
    assert_redirected_to organization_admins_path
    assert_equal "#{members(:dormant_member).name(:name_only => true)} has been added to the list of facilitators", flash[:notice]
    email = ActionMailer::Base.deliveries.last
    assert_equal email.subject, "No Subdomain Admin (Facilitator) invites you to be a facilitator!"
    email_html = get_html_part_from(email)
    assert_match /has invited you to join No Sub Domain Program/, email_html
    assert_match /Please get started by reviewing the program/, email_html
    assert_match /Accept and sign up/, email_html
  end

  def test_create_admin_failure
    current_member_is :f_admin

    post :create, params: { :member => {:name_with_email => "asdasdsaa"}}
    assert_redirected_to organization_admins_path
    assert_equal "Please choose users from the suggestion list", flash[:error]
  end

  def test_create_new_admin_success
    current_member_is :f_admin
    admin = members(:f_admin)
    update_custom_term_for_admin(admin)
    assert_difference "Member.count" do
      assert_difference "User.count", 5 do
        assert_difference "Password.count" do
          assert_emails 1 do
            post :create, params: { :member => {:first_name => "Mrudhukar", :last_name => "Batchu", :email => "mrudhukar@chronus.com"}, :message => "Hi"}
          end
        end
      end
    end

    member = Member.last
    assert member.admin?
    assert_redirected_to organization_admins_path
    assert_equal "#{member.name(:name_only => true)} has been added to the list of facilitators", flash[:notice]
  end

  def test_create_new_admin_failure
    current_member_is :f_admin

    assert_no_difference "Member.count" do
      assert_no_emails do
        post :create, params: { :member => {:first_name => "Mrudhukar", :last_name => "Batchu", :email => users(:f_admin).email}}
      end
    end

    assert_redirected_to organization_admins_path
    assert_equal "Please correct the below error(s) highlighted in red.", flash[:error]
  end

  def test_remove_admin_success
    current_member_is :f_admin
    members(:student_1).update_attribute :admin, true
    assert members(:student_1).reload.admin?
    student = members(:student_1)
    update_custom_term_for_admin(student)
    delete :destroy, params: { :id => members(:student_1).id}
    assert_redirected_to organization_admins_path
    assert_equal "#{members(:student_1).name(:name_only => true)} has been removed from the list of facilitators", flash[:notice]

    assert_false members(:student_1).reload.admin?
  end

  def test_remove_non_admin_failure
    current_member_is :f_admin
    assert_false members(:student_1).reload.admin?

    assert_record_not_found do
      delete :destroy, params: { :id => members(:student_1).id}
    end
  end

  def test_member_should_not_be_able_to_delete_program_admin
    current_member_is :f_admin
    members(:ram).promote_as_admin!
    programs(:albers).owner = users(:ram)
    programs(:albers).save
    assert_permission_denied do
      delete :destroy, params: { :id => members(:ram).id}
    end
  end

end
