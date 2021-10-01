module ApplicationControllerExtensions::NewRelic
  private

  def instrument_request_for_newrelic
    if request.xhr?
      NewRelic::Agent.set_transaction_name("#{NewRelic::Agent.get_transaction_name}-XHR")
    end
  end

  def add_custom_parameters_for_newrelic
    roles = current_user.present? ? current_user.role_names.join(", ") : "global / non logged in"
    NewRelic::Agent.add_custom_parameters 'Roles' => roles
  end

  def skip_apdex_for_newrelic
    if @current_organization && defined?(ApdexConstants)
      ignore_apdex
      ignore_enduser
    end
  end

  def set_org_id_and_program_id_for_newrelic
    NewRelic::Agent.add_custom_parameters 'Org_ID' => @current_organization.id if @current_organization.present?
    NewRelic::Agent.add_custom_parameters 'Prog_ID' => @current_program.id if @current_program.present?
  end

  # To add a custom attribute in newrelic to differentiate mobile app and mobile browser traffic.
  def set_traffic_origin_for_newrelic
    NewRelic::Agent.add_custom_parameters 'TrafficOrigin' => get_traffic_origin
  end

  def ignore_apdex
    NewRelic::Agent.ignore_apdex if defined?(ApdexConstants::SKIP_APDEX_LIST) && ApdexConstants::SKIP_APDEX_LIST.include?(@current_organization.id)
  end

  def ignore_enduser
    NewRelic::Agent.ignore_enduser if defined?(ApdexConstants::SKIP_ENDUSER_APDEX_LIST) && ApdexConstants::SKIP_ENDUSER_APDEX_LIST.include?(@current_organization.id)
  end

end
