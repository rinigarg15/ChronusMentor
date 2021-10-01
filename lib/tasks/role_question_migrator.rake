# bundle exec rake role_question_migrator:migrate_between_programs DOMAIN=<domain> SUBDOMAIN=<subdomain> SOURCE="p1" TARGET="p2"

namespace :role_question_migrator do
  desc "Copy role questions and match configs from one program to another"
  task migrate_between_programs: :environment do
    organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
    source_program = organization.programs.where(root: ENV["SOURCE"]).includes({ roles: [:translations, role_questions: :privacy_settings] }, :match_configs).first
    target_program = organization.programs.where(root: ENV["TARGET"]).includes({ roles: :translations }).first
    Common::RakeModule::Utils.execute_task(async_dj: true) do
      target_program.match_configs.delete_all

      role_question_ids_to_delete = target_program.role_questions.pluck(:id)
      RoleQuestion.where(id: role_question_ids_to_delete).destroy_all

      role_mapping = create_role_mapping(source_program, target_program)

      role_questions_mapping = migrate_role_questions(source_program, role_mapping)
      raise "Role Questions Count mismatch" if source_program.role_questions.count != target_program.role_questions.count

      unless ENV['SKIP_MATCH_CONFIGS'].present?
        migrate_match_configs(source_program, target_program, role_questions_mapping)
        raise "Match Configs Count mismatch" if source_program.match_configs.count != target_program.match_configs.count
      end

      User.es_reindex_for_profile_score(target_program.role_ids)
    end
    puts "Expire Cache fragments"
    ApplicationController.new.send(:expire_user_filters, target_program.id)
    puts "Delta Indexing Matching For Target program"
    Matching.perform_program_delta_index_and_refresh_with_error_handler(target_program.id)
  end

  def create_role_mapping(source_program, target_program)
    role_mapping = {}
    source_program.roles.each do |source_role|
      begin
        role_mapping[source_role.id] = target_program.roles.find{ |target_role| target_role.name == source_role.name }.id
      rescue
        raise "#{source_role.name} role not found"
      end
    end
    role_mapping
  end

  def migrate_role_questions(source_program, role_mapping)
    role_questions_mapping = {}
    source_program.role_questions.each do |source_role_question|
      target_role_id = role_mapping[source_role_question.role_id]
      next unless target_role_id
      target_role_question = source_role_question.dup
      target_role_question.role_id = target_role_id
      target_role_question.save!

      role_questions_mapping[source_role_question.id] = target_role_question.id

      source_role_question.privacy_settings.each do |source_privacy_setting|
        source_privacy_setting.dup.tap do |target_privacy_setting|
          target_privacy_setting.role_question_id = target_role_question.id
          target_privacy_setting.role_id = role_mapping[source_privacy_setting.role_id]
        end.save!
      end
    end
    role_questions_mapping
  end

  def migrate_match_configs(source_program, target_program, role_questions_mapping)
    source_program.match_configs.each do |source_match_config|
      target_match_config = source_match_config.dup
      target_match_config.program_id = target_program.id
      target_match_config.student_question_id = role_questions_mapping[source_match_config.student_question_id]
      target_match_config.mentor_question_id = role_questions_mapping[source_match_config.mentor_question_id]
      target_match_config.skip_matching_indexing = true
      target_match_config.save!
    end
  end

end
