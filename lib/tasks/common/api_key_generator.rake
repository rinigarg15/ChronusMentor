# USAGE: rake common:api_key_generator:generate DOMAIN=<domain> SUBDOMAIN=<subdomain> EMAIL=<admin-email>
# EXAMPLE: rake common:api_key_generator:generate DOMAIN="localhost.com" SUBDOMAIN="ceg"

namespace :common do
  namespace :api_key_generator do
    desc "Generate API Key"
    task generate: :environment do
      Common::RakeModule::Utils.execute_task do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        email = ENV["EMAIL"].presence || "mentor+api@chronus.com"
        api_member = organization.members.admins.find_by(email: email)
        raise "No organization admin with email '#{email}'!" if api_member.blank?

        api_member.enable_api! if api_member.api_key.blank?
        ChronusS3Utils::S3Helper.write_to_file_and_store_in_s3(api_member.api_key, "api_keys/#{Rails.env}/#{organization.id}", file_name: "#{api_member.id}_api")
        Common::RakeModule::Utils.print_alert_messages("All the API requests will be processed on behalf of member with email #{email}! Ensure that the customer is okay with it!")
        Common::RakeModule::Utils.print_alert_messages("Api key file is uploaded in S3 bucket #{APP_CONFIG[:chronus_mentor_common_bucket]} in the path 'api_keys/#{Rails.env}/#{organization.id}'")
        Common::RakeModule::Utils.print_success_messages("Contact Ops Team to generate shareable link with Validity as 7 days")
      end
    end
  end
end