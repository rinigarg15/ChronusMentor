# URL_UPDATE_USAGE:
#   bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [NEWDOMAIN=(newdomain)] [NEWSUBDOMAIN=(newsubdomain)] ([TOHTTP=true] | [TOHTTPS=true]) [ASSESS_ONLY=true] [CLONED_SOURCE_DB=(cloned source db)]
# ROOT_UPDATE_USAGE:
#   bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [ROOT=(root)] [NEWROOT=(newroot)]
# CHANGE OLD IDS IN ORG USAGE:
#   bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [NEWDOMAIN=(newdomain)] [NEWSUBDOMAIN=(newsubdomain)] [SOURCE_ENVIRONMENT=(source_environment)] [SOURCE_SEED=(source_seed)] [CHANGE_OLD_IDS=true]
#   bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [CHANGE_OLD_IDS=true]  [ASSESS_ONLY=true]
# ALL_URLS_UPDATE_USAGE(run both the commands below)
#   bundle exec rake common:url_updater:change_urls URL_TO_CHANGE='s3.amazonaws.com/chronus-mentor-assets' NEW_URL='chronus-mentor-assets-backup.s3-us-west-1.amazonaws.com'
#   bundle exec rake common:url_updater:change_urls URL_TO_CHANGE='chronus-mentor-assets.s3.amazonaws.com' NEW_URL='chronus-mentor-assets-backup.s3-us-west-1.amazonaws.com'
namespace :common do
  namespace :url_updater do
    desc 'Change Links across models present in the App'
    task change_urls: :environment do
      include Rails.application.routes.url_helpers
        options = {}
        options[:domain] = ENV["DOMAIN"] || DEFAULT_DOMAIN_NAME
        options[:subdomain] = ENV["SUBDOMAIN"]
        options[:root] = ENV["ROOT"]

        options[:new_domain] = ENV["NEWDOMAIN"] || options[:domain] || DEFAULT_DOMAIN_NAME
        options[:new_subdomain] = ENV["NEWSUBDOMAIN"] || options[:subdomain]
        options[:new_root] = ENV["NEWROOT"]
        
        options[:to_https] = ENV["TOHTTPS"]
        options[:to_http] = ENV["TOHTTP"]
        options[:assess_only] = ENV["ASSESS_ONLY"]

        options[:url_to_change] = ENV["URL_TO_CHANGE"]
        options[:new_url] = ENV["NEW_URL"]

        options[:source_environment] = ENV["SOURCE_ENVIRONMENT"]
        options[:source_seed] = ENV["SOURCE_SEED"]
        options[:change_old_ids] = ENV["CHANGE_OLD_IDS"].present? || false
        options[:cloned_source_db] = ENV["CLONED_SOURCE_DB"]

        url_updater = UrlUpdater.new(options)
        if options[:url_to_change] && options[:new_url]
          url_updater.update_all_urls_in_db
        else
          url_updater.update_all_urls_of_an_organization
        end
    end
  end
end