module Matching
  # Provides services for keeping the caching matching data store updated with changes
  # to the application data
  module Cache
    class Refresh
  
      extend Matching::ServiceHelper

      class << self
        def perform_program_delta_refresh(program_id)
          program = Matching.fetch_program(program_id)
          return unless program.present?

          start_time = Time.now
          match_client = Matching::Client.new(program)
          student_user_ids = program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
          
          DjSplit.new(queue_options: { queue: DjQueues::SPLIT }, split_options: {size: 200, by: 2}).enqueue(match_client, "bulk_match", student_user_ids)
    
          program.update_match_scores_range!
          reset_dynamic_partitioning_status(program_id)
          say "Matching Delta Build for Program: #{program.name} (#{program_id}) Time: #{Time.now - start_time}"
        end

        def perform_users_delta_refresh(user_ids, program_id)
          program, users = Matching.fetch_program_and_users(user_ids, program_id)
          return unless program.present?

          users.find_each do |user|
            perform_user_delta_refresh(user)
          end
        end

        def remove_user_cache(user_id, program_id)
          remove_mentor(user_id, program_id)
          remove_student(user_id, program_id)
        end

        #--It removes mentor key and corresponding value of mentor from mentor hash of each mentee.
        #--Only one score document(mentor_hash) of each mentee will be affected 
        #--Old min-max scores are computed and passed to update_program_match_scores_range_wrt_old_scores
        def remove_mentor(user_id, program_id)
          program = Matching.fetch_program(program_id)
          return unless program.present?

          student_ids = program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
          partition = program.get_partition_size_for_program
          partition_id = user_id%partition
          bulk_chunk_size = (student_ids.size)/MAX_BULK_SIZE + 1
          bulk_ids_hash = get_ids_hash_based_on_modulo(student_ids, bulk_chunk_size)
          scores_to_consider = compute_scores_to_consider_and_remove_mentor_key_value(user_id, bulk_ids_hash, partition_id)
          program.update_program_match_scores_range_wrt_old_scores(scores_to_consider.min, scores_to_consider.max)
        end

        #--All scores documents corresponding to mentee are deleted after getting 
        #--old min-max corresponding to it and passed to update_program_match_scores_range_wrt_old_scores
        def remove_student(user_id, program_id)
          program = Matching.fetch_program(program_id)
          return unless program.present?

          student_docs = Matching::Persistence::Score.where(student_id: user_id)
          if student_docs.present?
            scores_min, scores_max =  Matching::Database::Score.new.get_min_max_by_mentee_id(user_id)
            student_docs.delete_all
            program.update_program_match_scores_range_wrt_old_scores(scores_min, scores_max)
          end
        end

        private

        def reset_dynamic_partitioning_status(program_id)
          match_setting = Matching::Persistence::Setting.where(program_id: program_id).first
          match_setting.update_attributes!(dynamic_p: false)
        end

        def perform_user_delta_refresh(user)
          return remove_user_cache(user.id, user.program_id) unless user.is_mentor_or_student?

          program = user.program      
          match_client = Matching::Client.new(program)

          if user.is_mentor?
            measure "Build Mentor Matches of Program(#{program.id}) Mentor_id(#{user.id}) Time:#{Time.now}:" do
              student_ids = program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)    
              DjSplit.new(queue_options: {queue: DjQueues::SPLIT}, split_options: {size: 1000, by: 2}).enqueue(match_client, "bulk_mentor_match", student_ids, [user.id])
            end
          end

          if user.is_student?
            measure "Build Mentee Matches of Program(#{program.id}) Mentee_id(#{user.id}) Time:#{Time.now}:" do
              mentor_ids = program.get_user_ids_based_on_roles(RoleConstants::MENTOR_NAME)
              old_min_score, old_max_score = Matching::Database::Score.new.get_min_max_by_mentee_id(user.id) #max-min scores before update
              match_client.bulk_mentee_match([user.id], mentor_ids)
              program.update_match_scores_range_for_student!(user, old_min_score, old_max_score)
            end
          end
        end

        #--Read mentees documents in a bulk
        #--Update mentees documents in bulk
        def compute_scores_to_consider_and_remove_mentor_key_value(user_id, bulk_ids_hash, partition_id)
          scores_to_consider = []
          bulk_ids_hash.each do |_index_val, student_ids_array|
            bulk_read = Matching::Database::Score.new.find_by_mentee_array_and_partition_id(student_ids_array, partition_id)
            bulk_write = Matching::Database::BulkScore.new
            bulk_read.each do |student_cache|
              score = delete_mentor_score_from_hash(user_id, student_cache, bulk_write, partition_id)
              scores_to_consider << score if score.present?
            end
            bulk_write.execute()
          end
          scores_to_consider
        end

        #--Remove key and value of mentor from each mentor hash corresponding to particular partition id of each mentee
        def delete_mentor_score_from_hash(user_id, student_cache, bulk_write, partition_id)
          score = student_cache["mentor_hash"][user_id.to_s]
          student_id = student_cache["student_id"]
          bulk_write.delete({:student_id => student_id, :p_id => partition_id}, {"mentor_hash.#{user_id}" => ""})
          score.present? ? score.first : nil
        end

        def say(comment)
          Rails.logger.info comment
          puts comment
        end
      end
    end
  end
end