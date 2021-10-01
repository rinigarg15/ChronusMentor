require_relative './../test_helper.rb'

class DemoProgramsControllerTest < ActionController::TestCase

  def test_new_action_requires_super_login
    get :new
    assert_redirected_to super_login_path
  end

  def test_new_renders_after_super_login
    login_as_super_user
    get :new
    assert_response :success
    assert_template 'new'
  end

  def test_new_renders_with_existing_dj
    login_as_super_user
    Delayed::Job.create(priority: DjPriority::SALES_DEMO)
    get :new
    assert_response :success
    assert_template 'new'
    assert_match /Another program is being created currently. Please wait for sometime and refresh the page to create new program/, @response.body
  end

  def test_create_action_requires_super_login
    post :create
    assert_redirected_to super_login_path
  end

  def test_create_with_used_subdomain
    program_domain = programs(:albers).organization.program_domains.first
    program_domain.subdomain = "abcd.demo"
    program_domain.save!
    login_as_super_user
    post :create, params: { :organization => {:program_domain => {:subdomain => "abcd"}, :name => "aaaa"}}
    assert_equal "Web Address has already been taken", flash[:error]
    assert_response :success
  end

  def test_create_with_system_call_success
    login_as_super_user
    job_mock = mock()
    SalesDemoProgramCreatorJob.expects(:new).with({organization_name: "aaaa", subdomain: "bbbb.demo"}).once.returns(job_mock)
    Delayed::Job.expects(:enqueue).with(job_mock, priority: DjPriority::SALES_DEMO)
    post :create, params: { :organization => {:program_domain => {:subdomain => "bbbb"}, :name => "aaaa", :subscription_type => Organization::SubscriptionType::BASIC}}
  end

  def test_create_with_existing_dj
    login_as_super_user
    Delayed::Job.create(priority: DjPriority::SALES_DEMO)
    Delayed::Job.expects(:enqueue).never
    post :create, params: { :organization => {:program_domain => {:subdomain => "bbbb"}, :name => "aaaa", :subscription_type => Organization::SubscriptionType::BASIC}}
  end

  def test_check_status
    login_as_super_user
    error = assert_raise Exception do
      get :check_status, params: { :subdomain => "bbb&asd", :format => :js} # Invalid Subdomain
    end
    assert_equal "Invalid Subdomain", error.message
    get :check_status, xhr: true, params: { :subdomain => "bbb", :format => :js} # Valid Subdomain
    assert_response :success
    assert_equal "http://bbb.test.host/", assigns(:redirection_url)

    dj = Delayed::Job.create(priority: DjPriority::SALES_DEMO)
    get :check_status, xhr: true, params: { :subdomain => "bbb", :format => :js} # Valid Subdomain & task is still running
    assert_response :success
    assert_blank @response.body

    dj.update_attribute(:failed_at, Time.now.utc - 7.days)
    get :check_status, xhr: true, params: { :subdomain => "bbb", :format => :js} # Valid Subdomain & task is still running
    assert_response :success
    assert_equal "An error occured while creating program. Please contact administrator.", flash[:error]
    assert_equal "http://test.host/demo_programs/new", assigns(:redirection_url)

    get :check_status, xhr: true, params: { :subdomain => "bbb", :format => :js} # Valid Subdomain
    assert_response :success
    assert_equal "http://bbb.test.host/", assigns(:redirection_url)
  end

end