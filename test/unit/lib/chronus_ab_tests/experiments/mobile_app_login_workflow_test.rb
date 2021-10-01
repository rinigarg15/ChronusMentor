require_relative './../../../../test_helper.rb'

class Experiments::MobileAppLoginWorkflowTest < ActionView::TestCase
  include Experiments::MobileAppLoginWorkflow::FinishMobileAppExperiment

  def test_title
    assert_equal "Mobile App Login Workflow", Experiments::MobileAppLoginWorkflow.title
  end

  def test_description
    assert_equal "Mobile App Login Page either asks for the Program URL or Email Address", Experiments::MobileAppLoginWorkflow.description
  end

  def test_experiment_config
    config = Experiments::MobileAppLoginWorkflow.experiment_config
    assert_equal ['Enter Program URL', 'Enter Email Address'], config[:alternatives]
  end

  def test_enabled
    assert Experiments::MobileAppLoginWorkflow.enabled?
  end

  def test_control_alternative
    assert_equal 'Enter Program URL', Experiments::MobileAppLoginWorkflow.control_alternative
  end

  def test_is_experiment_applicable_for
    program = Program.first
    user = User.first
    assert Experiments::MobileAppLoginWorkflow.is_experiment_applicable_for?(program, user)
  end

  def test_show_email_address_form
    exp1 = Experiments::MobileAppLoginWorkflow.new(Experiments::MobileAppLoginWorkflow::Alternatives::ALTERNATIVE_B)
    assert exp1.show_email_address_form?

    exp2 = Experiments::MobileAppLoginWorkflow.new(Experiments::MobileAppLoginWorkflow::Alternatives::CONTROL)
    assert_false exp2.show_email_address_form?

    exp3 = Experiments::MobileAppLoginWorkflow.new
    assert_false exp3.show_email_address_form?
  end

  def test_event_label_id_for_ga
    exp1 = Experiments::MobileAppLoginWorkflow.new(Experiments::MobileAppLoginWorkflow::Alternatives::ALTERNATIVE_B)
    assert_equal Experiments::MobileAppLoginWorkflow::Alternatives::GA_EVENT_LABEL_ID_MAPPING[Experiments::MobileAppLoginWorkflow::Alternatives::ALTERNATIVE_B], exp1.event_label_id_for_ga

    exp2 = Experiments::MobileAppLoginWorkflow.new(Experiments::MobileAppLoginWorkflow::Alternatives::CONTROL)
    assert_equal Experiments::MobileAppLoginWorkflow::Alternatives::GA_EVENT_LABEL_ID_MAPPING[Experiments::MobileAppLoginWorkflow::Alternatives::CONTROL], exp2.event_label_id_for_ga
  end

  def test_finish_cross_server_experiments
    response = Net::HTTPResponse.new("V1", "200", "message")
    request = Net::HTTP::Post.new("http://mentor.test.host/mobile_v2/home/finish_mobile_app_login_experiment", 'Content-Type' => 'application/json')
    Net::HTTP::Post.expects(:new).with(URI("http://mentor.test.host/mobile_v2/home/finish_mobile_app_login_experiment"), 'Content-Type' => 'application/json').returns(request)
    Net::HTTP.any_instance.expects(:request).with(request).returns("response")
    assert_equal "response", Experiments::MobileAppLoginWorkflow.finish_cross_server_experiments("uniq_token")
  end

  def test_mobile_app_login_finish_experiment_cross_server
    self.expects(:finished_chronus_ab_test_only_use_cookie).once
    Experiments::MobileAppLoginWorkflow.expects(:finish_cross_server_experiments).with("uniq_token").never
    finish_mobile_app_login_experiment("uniq_token")

    modify_const(:APP_CONFIG, mobile_app_origin_server: false) do
      self.expects(:finished_chronus_ab_test_only_use_cookie).never
      Experiments::MobileAppLoginWorkflow.expects(:finish_cross_server_experiments).with("uniq_token")
      finish_mobile_app_login_experiment("uniq_token")
    end
  end

end