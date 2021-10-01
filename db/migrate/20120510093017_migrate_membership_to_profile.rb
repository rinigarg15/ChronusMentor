class MigrateMembershipToProfile< ActiveRecord::Migration[4.2]
  def up      
#   ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=0;"
#   ActiveRecord::Base.transaction do
#    puts "DEFINE CONSTANTS ##########################Start Time is - #{Time.now.strftime("%H:%M:%S")}"
#    define_constants
#    puts "DEFINE CONSTANTS ##########################End Time is - #{Time.now.strftime("%H:%M:%S")}"
#
#    puts "CREATE MEMBERSHIP SECTIONS ##########################Start Time is - #{Time.now.strftime("%H:%M:%S")}"
#    create_membership_sections
#    puts "CREATE MEMBERSHIP SECTIONS ##########################End Time is - #{Time.now.strftime("%H:%M:%S")}"
#
#    puts "MIGRATE QUESTIONS ##########################Start Time is - #{Time.now.strftime("%H:%M:%S")}"
#    migrate_membership_questions_to_profile_questions
#    puts "MIGRATE QUESTIONS ##########################End Time is - #{Time.now.strftime("%H:%M:%S")}"
#
#    puts "MIGRATE PENDING/REJECTED ##########################Start Time is - #{Time.now.strftime("%H:%M:%S")}"
#    handle_rejected_and_pending_requests
#    puts "MIGRATE PENDING/REJECTED ##########################End Time is - #{Time.now.strftime("%H:%M:%S")}"
#
#    puts "MIGRATE ACCEPTED ##########################Start Time is - #{Time.now.strftime("%H:%M:%S")}"
#    handle_accepted_requests_non_profile_question_answers
#    puts "MIGRATE ACCEPTED ##########################End Time is - #{Time.now.strftime("%H:%M:%S")}"
#   end
#   ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=1;"
  end

  def down
  end

  def define_constants
    org_attributes_to_select = "id, parent_id, type, allow_membership_requests, type, active, name"        
    prog_attributes_to_select = "programs.id, programs.parent_id, programs.type, programs.allow_membership_requests, programs.type, programs.active, programs.name"        
    rejected_or_pending_status = [MembershipRequest::Status::UNREAD, MembershipRequest::Status::REJECTED]

    active_organizations = Organization.active.all(:select => org_attributes_to_select, :include => [:sections])
    program_with_membership_enabled = Program.active.allowing_membership_requests.all(:select => prog_attributes_to_select)    
    organization_with_membership_enabled_ids =  program_with_membership_enabled.collect(&:organization).collect(&:id)
    @prog_id_hash = program_with_membership_enabled.group_by(&:id)
    @organization_id_hash = active_organizations.select{|org| organization_with_membership_enabled_ids.include?(org.id)}.group_by(&:id)

    @membership_questions_hash = MembershipQuestion.where(:program_id => @prog_id_hash.keys).order(:position).group_by(&:program_id)    

    accepted_membership_request_ids = MembershipRequest.select(:id).where(:program_id => @prog_id_hash.keys).accepted.collect(&:id)    
    @accepted_membership_anwers_array = MembershipAnswer.all(:include => [:membership_question, :membership_request], :conditions => {:membership_request_id => accepted_membership_request_ids})

    rejected_or_pending_membership_request_ids = MembershipRequest.select(:id).where(:program_id => @prog_id_hash.keys, :status => rejected_or_pending_status).collect(&:id)
    @rejected_or_pending_membership_anwers_array = MembershipAnswer.all(:include => [:membership_question, :membership_request], :conditions => {:membership_request_id => rejected_or_pending_membership_request_ids})
    @membership_request_with_dual_roles_ids = MembershipRequest.all(:include => :roles).select{|m| m.roles.size>1}.collect(&:id)

    @mem_prof_ques_map = Hash.new    
  end

  def create_membership_sections
    @organization_id_hash.each_pair do |org_id, org|
      section = org[0].sections.build(:title => "Membership Information")
      position = org[0].sections.order(:position).select(:position).last.position
      section.update_attributes(:position => position + 1, :default_field => false)
      section.save!
    end
    raise "Section not created for all organizations" unless Section.where(:title => "Membership Information").size == @organization_id_hash.keys.size
  end

  def migrate_membership_questions_to_profile_questions
    raise "Membership Profile Question already exist" unless RoleQuestion.where(:available_for => [RoleQuestion::AVAILABLE_FOR::BOTH, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS]).size == 0            
    @membership_questions_hash.each do |program_id, membership_questions|      
      program, organization = get_program_and_organization(program_id)      
      membership_questions.each do |mem_ques|         
        prof_ques = get_matching_profile_question(organization, mem_ques)                 
        if prof_ques.nil?          
          prof_ques = create_and_update_profile_question(organization, mem_ques)
        else          
          update_profile_question(prof_ques, mem_ques)
        end
        @mem_prof_ques_map[mem_ques] = prof_ques
      end
    end    
    raise "MembershipQuestion Count is Not Consistent" unless @membership_questions_hash.values.flatten.size == RoleQuestion.where(:available_for => [RoleQuestion::AVAILABLE_FOR::BOTH, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS]).size        
  end

  def handle_rejected_and_pending_requests
    raise "MembershipRequest Answers already exists" unless ProfileAnswer.where(:ref_obj_type => "MembershipRequest").size == 0
    puts "Total Rejected/Pending Requests : #{@rejected_or_pending_membership_anwers_array.size}"
    count = 0
    @rejected_or_pending_membership_anwers_array.each do |mem_ans|
      prof_ques = @mem_prof_ques_map[mem_ans.membership_question]
      invalid = !mem_ans.attachment? && prof_ques.file_type?
      count = count+1 if invalid
      build_profile_answer_for(prof_ques, mem_ans, mem_ans.membership_request) unless invalid
    end
#    raise "Profile Answers Not properly Mapped for Pending/Rejected Membership Requests" unless (@rejected_or_pending_membership_anwers_array.size-count) == ProfileAnswer.where(:ref_obj_type => "MembershipRequest").size
  end

  def handle_accepted_requests_non_profile_question_answers
    puts "Total Accepted Requests : #{@accepted_membership_anwers_array.size}"        
    membership_only_question_ids = RoleQuestion.select("id, profile_question_id, available_for").where(:available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS).collect(&:profile_question_id).uniq
    accepted_answers_of_membership_only_question_ids = @accepted_membership_anwers_array.select{|ans| membership_only_question_ids.include?(@mem_prof_ques_map[ans.membership_question].id)}

    accepted_ans_for_dual_role_mem_reqs = accepted_answers_of_membership_only_question_ids.select{|ans| @membership_request_with_dual_roles_ids.include?(ans.membership_request_id)}
    accepted_ans_for_non_dual_role_mem_reqs = accepted_answers_of_membership_only_question_ids - accepted_ans_for_dual_role_mem_reqs    
    
    accepted_ans_for_non_dual_role_mem_reqs.each do |mem_ans|              
      prof_ques = @mem_prof_ques_map[mem_ans.membership_question]      
      mem_req = mem_ans.membership_request                  
      build_profile_answer_for(prof_ques, mem_ans, mem_req)            
    end

    accepted_ans_for_dual_role_mem_reqs.each do |mem_ans|
      prof_ques = @mem_prof_ques_map[mem_ans.membership_question]      
      mem_req = mem_ans.membership_request                  
      unless mem_req.profile_answers.where(:profile_question_id => prof_ques.id).present? #Membership Request with both role names, the answer would have already got mapped for the other role
        build_profile_answer_for(prof_ques, mem_ans, mem_req)
      end
    end
  end

  def get_program_and_organization(program_id)
    program = @prog_id_hash[program_id][0]
    organization = @organization_id_hash[program.parent_id][0]
    [program, organization]
  end

  def get_matching_profile_question(organization, mem_ques)
    organization.profile_questions.each do |prof_ques|
      return prof_ques if similar_question?(prof_ques, mem_ques)
    end
    return nil
  end

  def similar_question?(prof_ques, mem_ques)
    prof_ques.question_type == mem_ques.question_type &&
      similar_content?(prof_ques.question_text, mem_ques.question_text) &&
      ((prof_ques.choice_based? && mem_ques.choice_based?) ? similar_choices?(prof_ques, mem_ques) : true)
  end
  
  def similar_choices?(prof_ques, mem_ques)    
    (prof_ques.default_choices.collect{|choice| choice.downcase.gsub(/\s/, '')} - mem_ques.default_choices.collect{|choice| choice.downcase.gsub(/\s/, '')}).empty?
  end

  def similar_content?(text1, text2)
    return true if text1.nil? and text2.nil?
    return false if text1.nil? or text2.nil?
    text1.downcase.gsub(/\s/, '') == text2.downcase.gsub(/\s/, '')
  end

  def create_and_update_profile_question(organization, mem_ques)
    prof_ques = organization.profile_questions.build(:question_text => mem_ques.question_text, :question_info => mem_ques.question_info, :question_type => mem_ques.question_type, :help_text => mem_ques.help_text)
    prof_ques.section = organization.sections.find_by(title: "Membership Information")
    prof_ques.save!
    role_ques = prof_ques.role_questions.build(:required => mem_ques.required, :available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    role_ques.role = mem_ques.roles[0]
    role_ques.save!    
    raise "Profile Question Wrongly Created/Repeated" if organization.profile_questions.where(:question_text => mem_ques.question_text, :question_info => mem_ques.question_info, :question_type => mem_ques.question_type).size > 1
    return prof_ques
  end

  def update_profile_question(prof_ques, mem_ques)
    role_q = prof_ques.role_questions.select{|r_q| r_q.role == mem_ques.roles[0]}
    if role_q.present?
      role_ques = role_q[0]
      role_ques.available_for = RoleQuestion::AVAILABLE_FOR::BOTH
    else
      role_ques = prof_ques.role_questions.build(:required => mem_ques.required, :available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
      role_ques.role = mem_ques.roles[0]
    end    
    raise "Role Question Wrongly Created" unless role_ques.program == mem_ques.program
    role_ques.save!
  end

  def build_profile_answer_for(prof_ques, mem_ans, ref_obj)
    if prof_ques.file_type?
      if mem_ans.attachment?
        begin
          prof_ans = prof_ques.profile_answers.build(:answer_text => mem_ans.answer_text)
          prof_ans.attachment = (PROFILE_ANSWER_ATTACHMENT_STORAGE_OPTIONS[:storage] == :s3) ? get_get_remote_data(mem_ans.attachment.url) : open(URI.parse("http://www.google.com/intl/en_com/images/srpr/logo3w.png"))
          prof_ans.ref_obj = ref_obj
          prof_ans.save!
          raise "Attachment not created" if mem_ans.attachment.url && !prof_ans.attachment.present?
        rescue => e
          puts "Answer is: #{mem_ans.id}"
        end
      end
    else
      prof_ans = prof_ques.profile_answers.new(:answer_text => mem_ans.answer_text, :ref_obj => ref_obj)
      if prof_ans.valid?
        prof_ans.save!
      else
        puts "#{mem_ans.id}.......#{prof_ques.id}"
      end
      
    end
  end

  def get_get_remote_data(url)
    io = open(URI.parse(url))
    def io.original_filename; base_uri.path.split('/').last; end
    io.original_filename.blank? ? nil : io
  end    
end
