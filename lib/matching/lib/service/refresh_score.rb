module Matching
  class RefreshScore
    attr_accessor :partition, :dynamic_partitioning

    def initialize(partition, dynamic_partitioning = false)
      self.partition              = partition
      self.dynamic_partitioning   = dynamic_partitioning
    end

    #--Update and Insert documents which includes that mentor_id
    def refresh_score_documents_wrt_mentor_update!(mentor_id, mentee_hash)
      student_ids_set = mentee_hash.keys
      bulk_write = Matching::Database::BulkScore.new
      update_records_wrt_mentor_update(mentor_id, mentee_hash, student_ids_set, bulk_write)
      bulk_write.execute()
    end

    #--Update and Insert complete documents of particular mentee id
    def refresh_score_documents!(mentor_hash_object, unique_stamp = nil)
      @unique_stamp = unique_stamp
      student_id = mentor_hash_object.mentee_id
      mentor_hash = mentor_hash_object.mentor_hash_with_partition
      bulk_write = Matching::Database::BulkScore.new
      partition_ids_updated = []
      partition_ids_updated = update_exiting_records(student_id, bulk_write, mentor_hash) unless self.dynamic_partitioning
      insert_remaining_records(student_id, partition_ids_updated, bulk_write, mentor_hash)
      bulk_write.execute()
      removing_old_documents(student_id) if self.dynamic_partitioning
    end

    private

    def get_partition_id_wrt_mentor_id(mentor_id)
      mentor_id%self.partition
    end

    def update_records_wrt_mentor_update(mentor_id, mentee_hash, student_ids, bulk_write)
      partition_id = get_partition_id_wrt_mentor_id(mentor_id)
      student_ids.each do |student_id|
        bulk_write.update({:student_id => student_id, :p_id => partition_id}, {"mentor_hash.#{mentor_id}" => mentee_hash[student_id]}, {upsert: true})
      end
    end

    def update_exiting_records(student_id, bulk_write, mentor_hash)
      partition_ids_updated = []
      bulk_read = Matching::Database::Score.new.find_by_mentee_id(student_id)
      bulk_read.each do |student_cache|
        partition_id = student_cache["p_id"]
        bulk_write.update({:student_id => student_id, :p_id => partition_id}, {:mentor_hash => mentor_hash[partition_id]}) unless mentor_hash[partition_id].nil?
        partition_ids_updated << partition_id
      end
      partition_ids_updated
    end

    def insert_remaining_records(student_id, partition_ids_updated, bulk_write, mentor_hash)
      (Array(0...@partition) - partition_ids_updated).each do |partition_id|
        options = {:student_id => student_id, :p_id => partition_id, :mentor_hash => mentor_hash[partition_id]}
        options[:t_s] = @unique_stamp if self.dynamic_partitioning
        bulk_write.insert(options)
      end
    end

    #--remove old scores documents, after inserting new documents during dynamic partitioning. It will use get_unique_stamp
    #--for finding new inserted documents and remove rest of them for particular mentee.
    def removing_old_documents(student_id)
      all_score_documents_ids = Matching::Persistence::Score.where(student_id: student_id).pluck(:id)
      inserted_score_document_ids = Matching::Persistence::Score.where(student_id: student_id, t_s: @unique_stamp).pluck(:id)
      Matching::Persistence::Score.where(:id.in => (all_score_documents_ids - inserted_score_document_ids)).delete_all
    end
  end
end