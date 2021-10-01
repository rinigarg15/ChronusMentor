# Usage: bundle exec rake mentoring_model_cloner:clone DOMAIN="chronus.com" SUBDOMAIN="walkthru" SOURCE_PROGRAM_ROOT="p1" TARGET_ROOTS="p2,p3"<optional> SOURCE_MENTORING_MODEL_IDS='1,2' SKIP_ROOTS='p3'<ROOT>
namespace :mentoring_model_cloner do
  desc "Clone Mentoring model in Master Program to Other Tracks"
  task clone: :environment do
    Common::RakeModule::Utils.execute_task do
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'], ENV['SOURCE_PROGRAM_ROOT'])
      source_program = programs[0]

      target_programs = organization.programs.where.not(id: source_program.id)
      target_programs = target_programs.where(root: ENV["TARGET_ROOTS"].split(",")) if ENV["TARGET_ROOTS"].present?
      target_programs = target_programs.where.not(root: ENV["SKIP_ROOTS"].split(",")) if ENV["SKIP_ROOTS"].present?

      source_mentoring_model_ids = ENV["SOURCE_MENTORING_MODEL_IDS"].split(",").map(&:to_i)
      source_mentoring_models = source_program.mentoring_models.where(id: source_mentoring_model_ids).includes(:translations)
      if source_mentoring_model_ids.size != source_mentoring_models.size
        raise "Source mentoring models with ids #{source_mentoring_model_ids - source_mentoring_models.collect(&:id)} not present"
      end

      errors = {}
      source_mentoring_models.each do |source_mentoring_model|
        target_programs.each do |target_program|
          puts "Cloning #{source_mentoring_model.title} in #{target_program.root}"
          begin
            raise "Mentoring model already exists" if target_program.mentoring_models.any?{ |mm| mm.title == source_mentoring_model.title }
            MentoringModel::Cloner.new(source_mentoring_model, source_mentoring_model.title, target_program).clone_objects!
          rescue => e
            errors["#{target_program.root} : #{source_mentoring_model.title}"] = e.message
          end
        end
      end
      Common::RakeModule::Utils.export_to_csv("/tmp/errors_#{Time.now.to_i}.csv", ["Program : Menotring Model", "Error"], errors)
      raise ActiveRecord::Rollback if errors.present?
    end
  end
end