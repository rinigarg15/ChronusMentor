#usage rake single_time:import_manager_attributes DOMAIN=<domain> SUBDOMAIN=<subdomain> MANAGER_QUESTION_ID=<id> FILE_NAME=<file_name> MANAGER_EMAIL_HEADER=<manager_email_header> MANAGER_FIRST_NAME_HEADER=<manager_first_name_header> MANAGER_LAST_NAME_HEADER=<manager_last_name_header>
#Example rake single_time:import_manager_attributes DOMAIN='localhost.com' SUBDOMAIN='susu' MANAGER_QUESTION_ID='100' FILE_NAME='user_details.csv' MANAGER_EMAIL_HEADER='Mgr email' MANAGER_FIRST_NAME_HEADER='Mgr first name' MANAGER_LAST_NAME_HEADER='Mgr last name'

namespace :single_time do
  desc "Import manager attributes"
  task import_manager_attributes: :environment do
    Common::RakeModule::Utils.execute_task do
      manager_email_header, manager_first_name_header, manager_last_name_header = [ENV["MANAGER_EMAIL_HEADER"], ENV["MANAGER_FIRST_NAME_HEADER"], ENV["MANAGER_LAST_NAME_HEADER"]].map{|header| header.to_html_id.to_sym }
      member_details = SmarterCSV.process(ENV["FILE_NAME"])
      headers = member_details.first.keys
      raise "Please pass manager headers" if ([manager_email_header, manager_first_name_header, manager_last_name_header] - headers).present?

      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'])[1]
      manager_question = organization.profile_questions.manager_questions.find_by(id: ENV["MANAGER_QUESTION_ID"])
      raise "Manager question with given id not found" unless manager_question.present?
      members = organization.members.index_by(&:email)
      errors_map = []

      answers_map = {}
      answers_scope = ProfileAnswer.where(ref_obj_type: Member.name, profile_question_id: manager_question.id).includes(:manager)
      answers_scope.find_each do |answer|
        answers_map[answer.ref_obj_id] = answer
      end

      member_details.each do |member_detail|
        begin
          email = member_detail[:email]
          member = members[email]
          raise "Member with email #{email} not found " unless member.present?
          manager_details = { email: member_detail[manager_email_header], first_name: member_detail[manager_first_name_header], last_name: member_detail[manager_last_name_header] }
          answer_text = if answers_map[member.id].present?
             { "existing_manager_attributes" => { answers_map[member.id].manager.id.to_s => manager_details } }
          else
            { "new_manager_attributes" => [manager_details] }
          end
          member.update_manager_answers(manager_question, answer_text)
        rescue => e
          errors_map << headers.map{ |h| member_detail[h] } + [e.message]
        end
        print "."
      end
      if errors_map.present?
        error_file_name = "#{Rails.root}/tmp/manager_import_error_#{Time.now.to_i}.csv"
        CSV.open(error_file_name, "w+") do |csv|
          csv << headers + ["Error"]
          errors_map.each{|e| csv << e }
        end
        Common::RakeModule::Utils.print_error_messages("Errors exported to #{error_file_name}")
      end
    end
  end
end