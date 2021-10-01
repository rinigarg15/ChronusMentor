# http://www.pendo.io/

module PendoHelper

  def render_pendo
    return unless track_in_pendo?

    # Use Strings, Numbers, or Bools for visitor/account information.
    # Reserved visitor keys: email and role
    # Reserved account keys: id, name, planLevel, planPrice and creationDate

    # https://app.pendo.io/setup?setupKey=eyJTdWJzY3JpcHRpb25OYW1lIjoiQ2hyb251cyIsIkhtYWMiOiI4S3g5aTY3Qk9saEN6dXRYSGxVQXdNaGpGcllBekhyR2NkNk1ySExvWFZRPSJ9

    GlobalizationUtils.run_in_locale(I18n.default_locale) do
      <<-PENDO
        <script>
          (function(p,e,n,d,o){var v,w,x,y,z;o=p[d]=p[d]||{};o._q=[];
          v=['initialize','identify','updateOptions','pageLoad'];for(w=0,x=v.length;w<x;++w)(function(m){
          o[m]=o[m]||function(){o._q[m===v[0]?'unshift':'push']([m].concat([].slice.call(arguments,0)));};})(v[w]);
          y=e.createElement(n);y.async=!0;y.src='https://cdn.pendo.io/agent/static/9c9ad613-27cd-4e74-692a-af035d9779b2/pendo.js';
          z=e.getElementsByTagName(n)[0];z.parentNode.insertBefore(y,z);})(window,document,'script','pendo');

          pendo.initialize({
            apiKey: "#{APP_CONFIG[:pendo_api_key]}",

            visitor: {
              id: "#{current_member.email}",
              memberId: "#{Rails.env}_#{current_member.id}",
              email: "#{current_member.email}",
              name: "#{current_member.name(name_only: true)}",
              globalAdmin: #{current_member.admin?},
              profileUrl: "#{member_url(current_member)}",
              environment: "#{Rails.env}"
            },

            account: {
              id: "#{Rails.env}_#{@current_organization.id}#{"_#{@current_program.id}" if @current_program.present?}",
              name: "#{@current_organization.account_name} - #{@current_organization.name}#{" - #{@current_program.name}" if @current_program.present?}",
              accountName: "#{@current_organization.account_name}",
              url: "#{program_context.url(true)}",
              creationDate: "#{program_context.created_at.to_date}",
              matchingMode: "#{@current_program.try(:matching_mode_string)}",
              engagementMode: "#{@current_program.try(:engagement_mode_string)}",
              mentorEnrollmentMode: "#{@current_program.try(:mentor_enrollment_mode_string)}",
              menteeEnrollmentMode: "#{@current_program.try(:mentee_enrollment_mode_string)}"
            },

            parentAccount: {
              id: "#{Rails.env}_#{@current_organization.id}",
              name: "#{@current_organization.name}",
              accountName: "#{@current_organization.account_name}",
              planLevel: "#{@current_organization.verbose_subscription_type}",
              url: "#{@current_organization.url(true)}",
              creationDate: "#{@current_organization.created_at.to_date}",
              nPrograms: #{@current_organization.programs_count},
              nActiveMembers: #{@current_organization.current_users_with_published_profiles_count},
              nOngoingConnections: #{@current_organization.groups.active.count}
            },

            events: {
              guidesLoaded: function() {
                #{'pendo.removeLauncher();' unless show_pendo_launcher?}
              }
            }
          });
        </script>
      PENDO
    end
  end

  private

  def track_in_pendo?
    pendo_tracking_enabled? && !working_on_behalf? && (current_member.admin? || (current_user.present? && current_user.is_admin?))
  end

  def pendo_tracking_enabled?
    PENDO_TRACKING_ENABLED && APP_CONFIG[:pendo_api_key].present?
  end

  def show_pendo_launcher?
    !mobile_device? || @show_pendo_launcher_in_all_devices
  end
end