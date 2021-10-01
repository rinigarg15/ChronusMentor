require File.dirname(__FILE__) + '/common/configuration'
require File.dirname(__FILE__) + '/service/service'
require File.dirname(__FILE__) + '/client/client'
require File.dirname(__FILE__) + '/indexer/indexer'

module Matching
  # Weight to be assigned when either student or mentor profile field is blank.
  EMPTY_WEIGHT = 0.0

  # The range in which to assign scores to documents.
  SCORE_RANGE = 0.1..0.9

  class << self
    def perform_full_index_and_refresh_later
      DJUtils.enqueue_unless_duplicates(queue: nil).perform_full_index_and_refresh(self)
    end

    def perform_full_index_and_refresh
      start_time = Time.now
      Program.active.pluck(:id).each do |program_id|
        perform_program_delta_index_and_refresh_with_error_handler(program_id)
      end
      Delayed::Job.where(queue: [DjQueues::MONGO_CACHE, DjQueues::MONGO_CACHE_HIGH_LOAD]).where("created_at <= ?", start_time).destroy_all
      puts "Perform Full Index and Refresh finishes in #{Time.now - start_time}"
    end

    def perform_program_delta_index_and_refresh_with_error_handler(program_id)
      begin
        perform_program_delta_index_and_refresh(program_id)
      rescue Exception => e
        Airbrake.notify(e)
        puts "!! perform_program_delta_index_and_refresh failed at #{Time.now} for program ID: #{program_id} with error: #{e.message}. Created Airbrake notification"
      end
    end

    def perform_clear_and_full_index_and_refresh
      MatchingDocument.destroy_all
      Matching::Persistence::Score.destroy_all
      Matching::Persistence::Setting.destroy_all
      perform_full_index_and_refresh
    end

    def perform_organization_delta_index_and_refresh(organization_id)
      Organization.find(organization_id).programs.active.pluck(:id).each do |program_id|
        perform_program_delta_index_and_refresh_with_error_handler(program_id)
      end
    end

    def perform_organization_delta_index_and_refresh_later(organization)
      organization = validate_organization(organization)
      return unless organization.present?

      DJUtils.enqueue_unless_duplicates(queue: nil).perform_organization_delta_index_and_refresh(self, organization.id)
    end

    def perform_program_delta_index_and_refresh_later(program)
      program = validate_program(program)
      return unless program.present?

      DJUtils.enqueue_unless_duplicates(queue: nil).perform_program_delta_index_and_refresh(self, program.id)
    end

    def perform_program_delta_index_and_refresh(program_id)
      existing_student_documents = MatchingDocument.where(program_id: program_id, mentor: false)
      existing_student_document_ids = existing_student_documents.map(&:id)
      existing_student_document_record_ids = existing_student_documents.map(&:record_id)
      existing_mentor_document_ids = MatchingDocument.where(program_id: program_id, mentor: true).pluck(:id)

      mentor_ids, student_ids = Matching::Indexer.perform_program_delta_index(program_id)

      if existing_student_document_ids.present? && existing_mentor_document_ids.present?
        MatchingDocument.where(id: existing_student_document_ids).where.not(record_id: student_ids).destroy_all
        MatchingDocument.where(id: existing_mentor_document_ids).where.not(record_id: mentor_ids).destroy_all
        Matching::Persistence::Score.where(:student_id.in => (existing_student_document_record_ids - student_ids)).destroy_all
      end
      Matching::Cache::Refresh.perform_program_delta_refresh(program_id)
    end

    def perform_users_delta_index_and_refresh_later(user_ids, program, options = {})
      program = validate_program(program)
      return unless program.present?

      queue_name = get_mongo_cache_queue_name(program.organization.id)
      DJUtils.enqueue_unless_duplicates(queue: queue_name).perform_users_delta_index_and_refresh(self, user_ids, program.id, options)
    end

    def perform_users_delta_index_and_refresh(user_ids, program_id, options = {})
      user_ids_for_cache_refresh = Matching::Indexer.perform_users_delta_index(user_ids, program_id, options)
      Matching::Cache::Refresh.perform_users_delta_refresh(user_ids_for_cache_refresh, program_id)
    end

    def remove_user_later(user_id, program)
      program = validate_program(program)
      return unless program.present?

      queue_name = get_mongo_cache_queue_name(program.organization.id)
      DJUtils.enqueue_unless_duplicates(queue: queue_name).remove_user(self, user_id, program.id)
    end

    def remove_user(user_id, program_id)
      MatchingDocument.where(record_id: user_id).destroy_all
      Matching::Cache::Refresh.remove_user_cache(user_id, program_id)
    end

    def remove_mentor_later(user_id, program)
      program = validate_program(program)
      return unless program.present?

      queue_name = get_mongo_cache_queue_name(program.organization.id)
      DJUtils.enqueue_unless_duplicates(queue: queue_name).remove_mentor(Matching::Cache::Refresh, user_id, program.id)
    end

    def remove_student_later(user_id, program)
      program = validate_program(program)
      return unless program.present?

      queue_name = get_mongo_cache_queue_name(program.organization.id)
      DJUtils.enqueue_unless_duplicates(queue: queue_name).remove_student(Matching::Cache::Refresh, user_id, program.id)
    end

    def fetch_program(program_id)
      program = Program.find_by(id: program_id)
      return validate_program(program)
    end

    def fetch_program_and_users(user_ids, program_id)
      program = fetch_program(program_id)
      return [] unless program.present?
      return [program, program.users.where(id: user_ids)]
    end

    def get_mongo_cache_queue_name(org_id)
      (MatchingHighLoadOrganizations::ORGANIZATION_IDS.include?(org_id) && Rails.env == "production") ?  DjQueues::MONGO_CACHE_HIGH_LOAD : DjQueues::MONGO_CACHE
    end

    private

    def validate_program(program)
      return unless program.present?
      return unless program.active?
      return unless program.matching_enabled?
      return program
    end

    def validate_organization(organization)
      return unless organization.present?
      return unless organization.active?
      organization
    end
  end
end