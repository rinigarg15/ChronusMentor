class Experiments::MobileAppLoginWorkflow < ChronusAbExperiment 
  module Alternatives
    CONTROL = 'Enter Program URL'
    ALTERNATIVE_B = 'Enter Email Address'

    GA_EVENT_LABEL_ID_MAPPING = {
      CONTROL => 1,
      ALTERNATIVE_B => 2      
    }
  end

  module FinishMobileAppExperiment
    def finish_mobile_app_login_experiment(uniq_token)
      if APP_CONFIG[:mobile_app_origin_server]
        finished_chronus_ab_test_only_use_cookie(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true)
      else
        Experiments::MobileAppLoginWorkflow.delay(queue: DjQueues::HIGH_PRIORITY).finish_cross_server_experiments(uniq_token)
      end
    end
  end

  class << self
    def title
      "Mobile App Login Workflow"
    end

    def description
      "Mobile App Login Page either asks for the Program URL or Email Address"
    end

    def experiment_config
      { 
        alternatives: [Alternatives::CONTROL, Alternatives::ALTERNATIVE_B]
      }
    end

    def enabled?
      true
    end

    def control_alternative
      Alternatives::CONTROL
    end

    def is_experiment_applicable_for?(_program, _user)
      true
    end

    def finish_cross_server_experiments(uniq_token)
      url = APP_CONFIG[:cors_origin].first + Rails.application.routes.url_helpers.mobile_v2_home_finish_mobile_app_login_experiment_path
      send_request(url, uniq_token)
    end

    private

    def send_request(url, uniq_token)
      url = URI(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true unless Rails.env.test?
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      request = Net::HTTP::Post.new(
        url,
        'Content-Type' => 'application/json'
      )
      request.body = JSON.dump({
        "uniq_token" => uniq_token
      })
      http.request(request)
    end
  end

  def show_email_address_form?
    running? && alternative == Alternatives::ALTERNATIVE_B
  end

  def event_label_id_for_ga
    Alternatives::GA_EVENT_LABEL_ID_MAPPING[alternative]
  end
end