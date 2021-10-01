class MeetingRequestPopulator < PopulatorTask
  def patch(options = {})
    return unless @options[:common]["flash_type"]
    program_ids = [@program.id]
    meeting_requests_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, meeting_requests_hsh) 
  end

  def add_meeting_requests(program_ids, meeting_requests_count, options = {})
    self.class.benchmark_wrapper "MeetingRequest" do
      status_in_ratio = []
      1.times { status_in_ratio << AbstractRequest::Status::NOT_ANSWERED }
      62.times { status_in_ratio << AbstractRequest::Status::ACCEPTED }
      7.times { status_in_ratio << AbstractRequest::Status::REJECTED }
      4.times { status_in_ratio << AbstractRequest::Status::WITHDRAWN }
      24.times { status_in_ratio << AbstractRequest::Status::CLOSED }
      status_in_ratio.shuffle!
      programs = Program.find(program_ids)
      programs.each do |program|
        admin_users = program.admin_users
        mentor_users = program.mentor_users
        mentor_users_limit = (mentor_users.size * (mentor_users.size + 1)) / 2
        mentor_users_indices = [mentor_users_limit-1]
        1.upto(mentor_users.size-1) { |i| mentor_users_indices << (mentor_users_indices[-1]-i) }
        mentor_users_indices.reverse!
        mentor_users_indices_mapper = {}
        mentor_users_indices.each_with_index { |x,i| mentor_users_indices_mapper[x] = i }
        student_users = program.student_users
        student_users_limit = (student_users.size * (student_users.size + 1)) / 2
        student_users_indices = [student_users_limit-1]
        1.upto(student_users.size-1) { |i| student_users_indices << (student_users_indices[-1]-i) }
        student_users_indices.reverse!
        student_users_indices_mapper = {}
        student_users_indices.each_with_index { |x,i| student_users_indices_mapper[x] = i }
        MeetingRequest.populate meeting_requests_count do |meeting_request|
          meeting_request.program_id = program.id
          meeting_request.created_at = rand((program.created_at)..(Time.now))
          meeting_request.updated_at = rand((meeting_request.created_at)..(Time.now))
          meeting_request.status = status_in_ratio.sample
          random_idx = rand(student_users_limit)
          meeting_request.sender_id = student_users[student_users_indices_mapper[student_users_indices.bsearch{|x|random_idx<=x}]].id
          random_idx = rand(mentor_users_limit)
          meeting_request.receiver_id = mentor_users[mentor_users_indices_mapper[mentor_users_indices.bsearch{|x|random_idx<=x}]].id
          meeting_request.show_in_profile = false
          meeting_request.message = Populator.sentences(1..4)
          meeting_request.type = MeetingRequest.name
          case meeting_request.status
          when AbstractRequest::Status::ACCEPTED
            meeting_request.acceptance_message = Populator.sentences(2..5)
            meeting_request.accepted_at = meeting_request.updated_at
          when AbstractRequest::Status::REJECTED
            meeting_request.response_text = Populator.sentences(2..5)
          when AbstractRequest::Status::WITHDRAWN
            meeting_request.response_text = Populator.sentences(2..5)
          when AbstractRequest::Status::CLOSED
            meeting_request.response_text = Populator.sentences(2..5)
            meeting_request.closed_by_id = admin_users.sample
            meeting_request.closed_at = meeting_request.updated_at
          end
        end
      end
      self.class.display_populated_count(program_ids.size * meeting_requests_count, "MeetingRequest")
    end
  end

  def remove_meeting_requests(program_ids, meeting_requests_count, options = {})
    self.class.benchmark_wrapper "Removing MeetingRequest" do
      MeetingRequest.where(program_id: program_ids).last(meeting_requests_count).each(&:destroy)
      self.class.display_deleted_count(program_ids.size * meeting_requests_count, "MeetingRequest")
    end
  end
end