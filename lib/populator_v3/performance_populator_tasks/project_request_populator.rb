class ProjectRequestPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["project_request_enabled?"]
    return unless @program.project_based?
    student_ids = @program.users.active.includes(:roles).select{|user| user.is_student?}.collect(&:id)
    project_requests_hsh = get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, student_ids)
    process_patch(student_ids, project_requests_hsh) 
  end

  def add_project_requests(student_ids, count, options = {})
    self.class.benchmark_wrapper "Project Requests" do
      program = options[:program]
      group_ids = program.groups.pending.pluck(:id)
      student_role_id = program.find_role(RoleConstants::STUDENT_NAME).id
      temp_group_ids = group_ids.dup
      temp_student_ids = student_ids * count
      ProjectRequest.populate(student_ids.size * count, :per_query => 10_000) do |req|
        temp_student_ids = student_ids.dup if temp_student_ids.blank?
        req.sender_id = student_ids.shift
        req.program_id = program.id
        req.group_id = temp_group_ids.shift
        if req.group_id.nil?
          temp_group_ids = group_ids.dup
          req.group_id = temp_group_ids.shift
        end
        req.message = Populator.words(8..10)
        req.status = [AbstractRequest::Status::NOT_ANSWERED]
        req.sender_role_id = student_role_id
        self.dot
      end
      self.class.display_populated_count(student_ids.size * count, "Project Request")
    end
  end

  def remove_project_requests(student_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Faciliation Messages................" do
      program = options[:program]
      project_request_ids = program.project_requests.where(:sender_id => student_ids).select([:id, :sender_id]).group_by(&:sender_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.project_requests.where(:id => project_request_ids).destroy_all
      self.class.display_deleted_count(student_ids.size * count, "Project Request")
    end
  end
end