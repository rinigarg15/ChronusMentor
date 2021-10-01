class MentorRequestPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    student_ids = @program.users.active.includes([:roles]).select{|user| user.is_student?}.collect(&:id)
    @options[:mentor_ids] = @program.users.active.includes([:roles]).select{|user| user.is_mentor?}.collect(&:id)
    mentor_requests_hsh = get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, student_ids)
    process_patch(student_ids, mentor_requests_hsh) 
  end

  def add_mentor_requests(student_ids, count, options = {})
    self.class.benchmark_wrapper "Mentor Requests" do
      options.reverse_merge!(additional_requests: true)
      temp_student_ids  = student_ids * count
      program = options[:program]
      MentorRequest.populate(student_ids.size * count, :per_query => 10_000) do |mentor_request|
        mentor_request.program_id = program.id
        mentor_request.status = AbstractRequest::Status.all + [AbstractRequest::Status::NOT_ANSWERED]*2
        mentor_request.receiver_id = options[:mentor_ids].sample
        mentor_request.sender_id = temp_student_ids.shift
        mentor_request.response_text = (mentor_request.status == AbstractRequest::Status::REJECTED) ? Populator.sentences(2..5) : nil
        mentor_request.message = Populator.paragraphs(1..3)
        mentor_request.type = MentorRequest.to_s
        mentor_request.show_in_profile = true
        mentor_request.created_at = program.created_at
        mentor_request.updated_at = program.created_at..Time.now
        mentor_request.closed_at = Time.now if mentor_request.status == AbstractRequest::Status::CLOSED
        self.dot
      end
      self.class.display_populated_count(student_ids.size * count, "Mentor Request")
    end
  end

  def remove_mentor_requests(student_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentor Requests................" do
      program = options[:program]
      mentor_request_ids = program.mentor_requests.where(:sender_id => student_ids).select([:id, :sender_id]).group_by(&:sender_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.mentor_requests.where(:id => mentor_request_ids).destroy_all
      self.class.display_deleted_count(student_ids.size * count, "Mentor Request")
    end
  end
end