#Usage : rake single_time:get_non_signed_up_members DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma separated roots>
#Example : rake single_time:get_non_signed_up_members DOMAIN="chronus.com" SUBDOMAIN="walkthru" ROOTS="p1,p2"

module STATUS
  DELIVERED = "delivered"
  FAILED = "failed"
  OPENED = "opened"
  CLICKED = "clicked"
end

namespace :single_time do
  desc "Get members who submitted email but dint sign up"
  task get_non_signed_up_members: :environment do
    mg_client = Mailgun::Client.new(APP_CONFIG[:mailgun_api_key])
    mg_events = Mailgun::Events.new(mg_client, MAILGUN_DOMAIN)
    programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])
    program_names = Program::Translation.pluck(:name)
    raise "Multiple programs with same name" unless programs.collect{ |program| program_names.count(program.name) == 1 }.all?

    program_specific_mail_sent_emails_event_map = {}
    program_existing_user_emails_map = {}
    events_array = [STATUS::FAILED, STATUS::DELIVERED, STATUS::OPENED, STATUS::CLICKED]
    programs.each do |program|
      program_existing_user_emails_map[program] = (program.membership_requests.pluck(:email) + program.users.joins(:member).pluck("members.email")).uniq
      program_specific_mail_sent_emails_event_map[program] = {}
      events_array.each do |event|
        program_specific_mail_sent_emails_event_map[program][event] = []
        puts "Getting emails with subject 'Complete signing-up for #{program.name}' and event '#{event}'"
        result = mg_events.get({
          begin: 31.days.ago.utc.to_i,
          end: Time.now.utc.to_i,
          subject: "Complete signing-up for #{program.name}",
          event: event
        })
        while (items_array = result.to_h['items']).present?
          program_specific_mail_sent_emails_event_map[program][event] += items_array.collect{ |item_hash| item_hash["recipient"] }
          result = mg_events.next
        end
        program_specific_mail_sent_emails_event_map[program][event].uniq!
      end
    end

    program_specific_mail_sent_emails_event_map.each do |program, mail_sent_emails_event_map|
      mail_sent_emails_event_map.each do |event, _|
        event_position = events_array.index(event)
        program_specific_mail_sent_emails_event_map[program][event] -= program_specific_mail_sent_emails_event_map[program].slice(*events_array[event_position + 1..events_array.length - 1]).values.flatten
        program_specific_mail_sent_emails_event_map[program][event] -= program_existing_user_emails_map[program]
      end
    end

    file_name = "#{Rails.root}/tmp/non_signed_up_member_emails_#{Time.now.to_i}.csv"
    CSV.open(file_name, "w+") do |csv|
      csv << ["Program", "Email", "Status"]
      program_specific_mail_sent_emails_event_map.each do |program, event_mail_sent_emails_hash|
        event_mail_sent_emails_hash.each do |event, mail_sent_emails|
          mail_sent_emails.each { |mail_sent_email| csv << [program.name, mail_sent_email, event] }
        end
      end
    end
    Common::RakeModule::Utils.print_success_messages("Exported non signed up members to #{file_name}")
  end
end
