#Example rake single_time:import_question_choices DOMAIN='chronus.com' SUBDOMAIN='susu' PROFILE_QUESTION_IDS='123, 234' CHOICES='["1,0","2,0","3,0"]' DESTROY_PROFILE_ANSWERS=true

namespace :single_time do
  desc "Import question choices"
  task import_question_choices: :environment do
    Common::RakeModule::Utils.execute_task do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'])[1]
      profile_question_ids = ENV["PROFILE_QUESTION_IDS"].split(",").map(&:to_i)
      question_choices = eval(ENV["CHOICES"])
      profile_questions = organization.profile_questions.where(id: profile_question_ids).includes(:profile_answers)
      raise "Questions with ids #{profile_question_ids - profile_questions.collect(&:id)} not found" if profile_questions.size != profile_question_ids.count
      profile_questions.each do |profile_question|
        raise "Non choice based question #{profile_question.id}" unless profile_question.choice_or_select_type?
        if ENV["DESTROY_PROFILE_ANSWERS"].to_s.to_boolean
          profile_question.profile_answers.destroy_all
        else
          raise "Profile answers present for question #{profile_question.id}" if profile_question.profile_answers.present?
        end
        profile_question.question_choices.destroy_all
        question_choices.each_with_index do |choice, i|
          question_choice = profile_question.question_choices.new
          question_choice.text = choice
          question_choice.position = i + 1
          question_choice.save!
          print "."
        end
      end
      Matching.perform_organization_delta_index_and_refresh(organization.id) if profile_questions.collect(&:has_match_configs?).any?
    end
  end
end