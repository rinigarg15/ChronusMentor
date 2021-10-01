# = Chronus Profile Matching
#
# Provides the data structure and functionality required for matching profiles.
#
# Vikram Venkatesan  (mailto:vikram@chronus.com)
# Copyright (c) 2009 Chronus Corporation
#
require File.dirname(__FILE__) + '/data_types/abstract_type'
require File.dirname(__FILE__) + '/data_types/collection_type'
require File.dirname(__FILE__) + '/data_types/chronus_array'
require File.dirname(__FILE__) + '/data_types/chronus_ordered_array'
require File.dirname(__FILE__) + '/data_types/chronus_location'
require File.dirname(__FILE__) + '/data_types/chronus_string'
require File.dirname(__FILE__) + '/data_types/chronus_text'
require File.dirname(__FILE__) + '/data_types/chronus_educations'
require File.dirname(__FILE__) + '/data_types/chronus_experiences'
require File.dirname(__FILE__) + '/data_types/chronus_mis_match'
require File.dirname(__FILE__) + '/persistence/data_field'
require File.dirname(__FILE__) + '/persistence/score'
require File.dirname(__FILE__) + '/persistence/setting'
require File.dirname(__FILE__) + '/interface/data_field'
require File.dirname(__FILE__) + '/interface/document'
require File.dirname(__FILE__) + '/interface/mentor_hash'
require File.dirname(__FILE__) + '/interface/mentee_hash'
require File.dirname(__FILE__) + '/database/matching_database'
require File.dirname(__FILE__) + '/database/bulk_score'
require File.dirname(__FILE__) + '/database/score'
require File.dirname(__FILE__) + '/database/setting'
require File.dirname(__FILE__) + '/refresh_score'
require File.dirname(__FILE__) + '/service_helper'

module Matching
  # Provides the matching service for computing the match between student(s)
  # and mentors in a program.
  class Service
    attr_accessor :configuration, :program_id, :program 

    #--PARTITION_BASE is the value by which the number of partition of the program is decided. 
    #--partition size = number_of mentors/PARTITION_BASE + 1
    PARTITION_BASE = 100

    include ServiceHelper

    # Constructor.
    #
    # Params:
    # *<tt>config_opts</tt> : options for configuring on what data to perform
    # matching with. For example, passing config_opts[:program_id] = 15 restricts
    # the matching within the mentors in the program with id 15.
    #
    def initialize(configuration, config_opts = {})
      self.configuration    = configuration
      self.program = config_opts[:program]
      self.program_id = @program.id
    end

    #
    # Computes cache for the given student ids against the mentor ids in the
    # +mentor_documents+ collection.
    #
    #--------------------------------Dynamic Partitioning--------------------------------- 
    #--Here dynamic partioning is used for controlling the size of a mentee score document 
    #--as the number of mentors increases.
    #--Whenever perform_program_delta_index_and_refresh will run, it will check the number 
    #--of mentors in the program and compare with it with partition attribute of program. 
    #--If it differs it will update @dynamic_partitioning variable to true and following 
    #--will take place:
    #-- > Update partition attribute of program.
    #-- > Insert new sets of documents with new sets of partitions and delete old once
    #-- > Increase and decrease partition size without any downtime
    #
    #---------------------------bulk_match_complete------------------------------
    #--Compute mentor hash of each mentee and update/insert documents corresponding to it
    #
    def bulk_match_complete(student_ids = [])
      mentor_ids = @program.get_user_ids_based_on_roles(RoleConstants::MENTOR_NAME)
      setup_data_fields(student_ids, mentor_ids)
      init_dynamic_partitioning_required!

      @student_ids.each do |student_id|
        unique_stamp = get_unique_stamp
        #--Compute mentor hash
        mentor_hash_object = Matching::Interface::MentorHash.new(student_id, @partition)
        student_fields = @student_data_fields[student_id]
        @mentor_ids.each do |mentor_id|
          mentor_fields = @mentor_data_fields[mentor_id]
          mentor_hash_object.add_to_mentor_hash(mentor_id, get_mentor_mentee_score(student_fields, mentor_fields, @conf_mappings, student_id, mentor_id))
        end
        #--Commit to Database
        @refresh_score.refresh_score_documents!(mentor_hash_object, unique_stamp) 
      end
    end

    #--Compute mentee hash for each mentor and update/insert documents corresponding to documents 
    #--to which mentor belongs
    def delta_mentor_match(student_ids = [], mentor_ids = []) 
      setup_data_fields(student_ids, mentor_ids)

      @mentor_ids.each do |mentor_id|
        #--Compute mentee Hash
        mentee_hash_object = Matching::Interface::MenteeHash.new(mentor_id, @student_ids.size)
        mentor_fields = @mentor_data_fields[mentor_id]
        @student_ids.each do |student_id|
          student_fields = @student_data_fields[student_id]
          mentee_hash_object.add_to_mentee_hash(student_id, get_mentor_mentee_score(student_fields, mentor_fields, @conf_mappings, student_id, mentor_id))
        end
        mentee_hash = mentee_hash_object.mentee_hash
        #--Commit to Db
        mentee_hash.each do |_index_val, student_ids_hash|
          @refresh_score.refresh_score_documents_wrt_mentor_update!(mentor_id, student_ids_hash)
        end
        #--Update Program's min-max score range if max_score exceeds or min_score shorts Program's max-min scores
        update_match_score_range_for_mentor_update!(@program, mentee_hash_object.min_score, mentee_hash_object.max_score)
      end
    end

    #--Compute mentor hash of each mentee and update/insert documents corresponding to it
    def delta_mentee_match(student_ids = [], mentor_ids = [])
      setup_data_fields(student_ids, mentor_ids) 

      @student_ids.each do |student_id|
        #--Compute mentor hash
        mentor_hash_object = Matching::Interface::MentorHash.new(student_id, @partition)
        student_fields = @student_data_fields[student_id]
        @mentor_ids.each do |mentor_id|
          mentor_fields = @mentor_data_fields[mentor_id]
          mentor_hash_object.add_to_mentor_hash(mentor_id, get_mentor_mentee_score(student_fields, mentor_fields, @conf_mappings, student_id, mentor_id))
        end
        #--Commit to Database
        @refresh_score.refresh_score_documents!(mentor_hash_object)
      end
    end

    def match_single_config(mentor_question, student_question, not_match, hit_count, weight_and_threshold_and_details, options = {})
      weight, threshold, operator, matching_details = weight_and_threshold_and_details
      match_details = (mentor_question.nil? || student_question.nil?) ? (options[:get_common_data] ? {score: Matching::EMPTY_WEIGHT, common_values:[]} : Matching::EMPTY_WEIGHT) : mentor_question.match(student_question, {matching_details: matching_details, get_common_data: options[:get_common_data]})
      with_common_data = options[:get_common_data] && match_details.is_a?(Hash)
      current_match =  with_common_data ? match_details[:score] : match_details
      check_threshold = threshold.present? && ((MatchConfig::Operator.lt == operator) ? current_match < threshold : current_match > threshold)

      if check_threshold
        not_match = true
      else
        hit_count += (current_match * weight)
      end
      with_common_data ? [hit_count, not_match, match_details[:common_values]] : [hit_count, not_match]
    end

    def get_data_fields_for_match_details(user_ids, is_mentor)
      documents = build_documents(user_ids, is_mentor)
      data_fields = {}
      documents.each{|doc| data_fields[doc.record_id] = doc.data_fields_by_name}
      data_fields
    end

    def get_match_details(student_id, mentor_id)
      student_data_fields = get_data_fields_for_match_details([student_id], false)[student_id]
      mentor_data_fields = get_data_fields_for_match_details([mentor_id], true)[mentor_id]
      conf_mappings = self.configuration.field_mappings
      if mentor_data_fields.present? && student_data_fields.present?
        return get_mentor_mentee_score(student_data_fields, mentor_data_fields, conf_mappings, student_id, mentor_id, get_common_data: true)
      else
        return []
      end
    end

    private

    #--Initialize instance variable for bulk match and delta match
    def setup_data_fields(student_ids, mentor_ids)
      @partition = @program.get_partition_size_for_program
      stud_docs = build_documents(student_ids, false)
      ment_docs = build_documents(mentor_ids, true)
      @student_data_fields = {}
      @mentor_data_fields = {}
      stud_docs.each{|doc| @student_data_fields[doc.record_id] = doc.data_fields_by_name}
      ment_docs.each{|doc| @mentor_data_fields[doc.record_id] = doc.data_fields_by_name}
      @conf_mappings = self.configuration.field_mappings
      @max_hits = self.configuration.max_hits
      @max_hits_zero = (@max_hits == 0)
      @student_ids = stud_docs.collect(&:record_id)
      @mentor_ids = ment_docs.collect(&:record_id)
      @refresh_score = Matching::RefreshScore.new(@partition)
    end

    #--Create an array of Matching::Interface::Document objects from mysql MatchingDocument documents
    def build_documents(user_ids, is_mentor)  
      modified_docs = []
      sliced_user_ids = user_ids.each_slice(5000)     
      sliced_user_ids.each do |sliced_ids|
        documents = MatchingDocument.where(:program_id => self.program_id, :mentor => is_mentor, :record_id => sliced_ids)
        documents.each do |document|
          modified_docs << Matching::Interface::Document.new(document)
        end
      end
      modified_docs
    end

    def is_mentor_manager?(student_fields, mentor_fields)
      mentor_question = mentor_fields[Matching::Configuration.name_from_field_spec([Manager, "Manager Question Mentor"])]
      student_question = student_fields[Matching::Configuration.name_from_field_spec([Manager, "Manager Question Mentee"])]
      mentor_question.present? && student_question.present? && !student_question.match(mentor_question)
    end

    def is_past_mentor?(student_fields, mentor_fields)
      mentor_question = mentor_fields[Matching::Configuration.name_from_field_spec([User, "Past Mentors Question Mentor"])]
      student_question = student_fields[Matching::Configuration.name_from_field_spec([User, "Past Mentors Question Mentee"])]
      mentor_question.present? && student_question.present? && !student_question.match(mentor_question)
    end

    def is_mismatch(program, student_fields, mentor_fields)
      (program.prevent_manager_matching && is_mentor_manager?(student_fields, mentor_fields)) ||
      (program.prevent_past_mentor_matching && is_past_mentor?(student_fields, mentor_fields))
    end

    def get_partition_size
      PARTITION_BASE
    end

    def dynamic_partitioning_needed?(new_partition_size)
      match_setting = Matching::Persistence::Setting.where(program_id: self.program_id).first
      if (@partition != new_partition_size)
        match_setting.update_attributes!({partition: new_partition_size, dynamic_p: true})
      else
        dynamic_partitioning_status = match_setting.dynamic_p
        if dynamic_partitioning_status.nil? || dynamic_partitioning_status == false
          return false
        end
      end
      return true
    end

    #--update @partition and check whether dynamic partitioning is required?
    def init_dynamic_partitioning_required!
      new_partition_size = (@mentor_ids.size)/get_partition_size + 1
      @dynamic_partitioning = dynamic_partitioning_needed?(new_partition_size)
      @partition = new_partition_size
      if @dynamic_partitioning
        @refresh_score.dynamic_partitioning = true
        @refresh_score.partition = @partition
      end
    end

    def get_mentor_mentee_score(student_fields, mentor_fields, conf_mappings, student_id, mentor_id, options = {})
      hit_count, not_match = [0.0, false]
      details = []
      if (mentor_id == student_id) || is_mismatch(@program, student_fields, mentor_fields)
        not_match = true
      else
        conf_mappings.each_pair do |field_pair, weight_and_threshold_and_details|
          hit_count, not_match = [0.0, false] if options[:get_common_data]
          mentor_question = mentor_fields[field_pair[0]]
          student_question = student_fields[field_pair[1]]
          if student_question.present? || mentor_question.present?
            hit_count, not_match, match_details = match_single_config(mentor_question, student_question, not_match, hit_count, weight_and_threshold_and_details, get_common_data: options[:get_common_data])
            details << [hit_count, weight_and_threshold_and_details[4], match_details] unless not_match
          end
        end
      end
      if options[:get_common_data]
        return details
      else
        return [(not_match || @max_hits_zero) ? 0.0 : (hit_count.to_f / @max_hits), not_match]
      end
    end
  end
end