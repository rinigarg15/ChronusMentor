module AnalyticsHelper
  
  # To track multiple subdomains within a domain. See:
  #  http://www.google.com/support/googleanalytics/bin/answer.py?hl=en&answer=55524
  def render_gtac(track_info = nil)
    return unless request_trackable?
    domain_to_use = @current_organization ? @current_organization.domain : DEFAULT_DOMAIN_NAME
    str = track_info ? "\"#{track_info}\"" : nil
    dimensions_hash = get_dimensions_hash
    <<-GTAC
      <script>
        (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
        m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
        })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

        ga('create', '#{APP_CONFIG[:google_analytics_id]}', {'cookieDomain': '#{domain_to_use}', 'legacyCookieDomain': '#{domain_to_use}'});
        #{ "ga('set', 'page', #{str});" if str }
        Analytics.setGADimensionMapping(#{dimension_mapping.to_json});
        Analytics.setGADimensions(#{dimensions_hash.to_json});
        jQuery.each(GADimensions, function(key, value) {
          ga('set', key, value);
        });
        ga('set', 'anonymizeIp', true);
        ga('send', 'pageview', Analytics.getPageUrlForGA(window.location.href));
      </script>
    GTAC
  end

  # ANALYTICS_TRACKING_ENABLED is true for production and test enviroments.
  def request_trackable?
    ANALYTICS_TRACKING_ENABLED && !cookies[GOOGLE_ANALYTICS_IGNORE_COOKIE]
  end

  def get_dimensions_hash
    dimensions_hash = {
      org_name: @current_organization ? "#{@current_organization.account_name} - #{@current_organization.name}" : "",
      is_logged_in: logged_in_at_current_level?,
      user_role: get_user_role_for_ga(current_user),
      work_on_behalf_status: working_on_behalf?,
      mentoring_mode: get_mentoring_mode_for_ga(@current_program),
      track_level_connection_status: get_track_level_connection_status(current_user),
      org_level_connection_status: get_org_level_connection_status(wob_member),
      explicit_preference_configured: get_explicit_preference_configuration_for_user(current_user)
    }
    dimensions_hash[:is_admin] = dimensions_hash[:is_logged_in] ? program_view? ? current_user.is_admin? : current_member.admin? : false
    dimensions_hash
  end

  def dimension_mapping
    {
      org_name: 1,
      is_logged_in: 2,
      is_admin: 3,
      mentoring_mode: 4,
      user_role: 5,
      work_on_behalf_status: 6,
      org_level_connection_status: 7,
      track_level_connection_status: 8,
      explicit_preference_configured: 9
    }
  end
end
