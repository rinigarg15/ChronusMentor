class GroupMentoringEqualMentorMenteePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return unless @options[:common]["group_mentoring_enabled?"]
    group_count = @counts_ary.first
    mentor_count = @options[:args]["mentor"]
    mentee_count = @options[:args]["mentee"]
    groups = @program.groups.includes(:members).select{|group| group.members.count > 2}
    group_ids = groups.collect(&:id)
    return if groups.select{|group| (group.mentors.count == mentor_count && group.students.count == mentee_count)}.count > 0
    populate_group_mentoring(@program, group_count, mentor_count, mentee_count)
    copy_group_permissions(group_ids)
  end
end