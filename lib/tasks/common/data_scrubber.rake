# USAGE: rake common:data_scrubber:scrub DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> SCRUB_ITEM=<item_name> IDS=<object_ids>
# EXAMPLES:
# rake common:data_scrubber:scrub DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1" SCRUB_ITEM="program_events"
# rake common:data_scrubber:scrub DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1" SCRUB_ITEM="program_events" IDS="1,2,3"

namespace :common do
  namespace :data_scrubber do
    desc "Scrub items from specified program(s)"
    task scrub: :environment do
      Common::RakeModule::Utils.execute_task do
        programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])
        programs << nil if programs.empty?

        scrub_item = ENV["SCRUB_ITEM"]
        scrub_method = "scrub_#{scrub_item}"
        programs.each do |program|
          data_scrubber = DataScrubber.new(program: program, organization: organization)
          raise "Invalid SCRUB_ITEM '#{scrub_item}'" if !data_scrubber.respond_to?("scrub_#{scrub_item}")

          puts "Scrubbing #{scrub_item} from #{(program.presence || organization).url}..."
          if ENV["IDS"].present?
            object_ids = ENV["IDS"].split(",").map(&:to_i)
            data_scrubber.send(scrub_method, object_ids)
          else
            data_scrubber.send(scrub_method)
          end
          Common::RakeModule::Utils.print_success_messages("Scrub of #{scrub_item} from #{(program.presence || organization).url} is complete!")
        end
      end
    end
  end
end