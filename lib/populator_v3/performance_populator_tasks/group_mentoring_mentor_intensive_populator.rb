class GroupMentoringMentorIntensivePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return unless @options[:common]["group_mentoring_enabled?"]
    mentor_count = @options[:args]["mentor"]
    mentee_count = @options[:args]["mentee"]
    groups = @program.groups.includes(:members).select{|group| group.members.count > 2}
    group_ids = groups.collect(&:id)
    group_count = @counts_ary.first
    return if groups.select{|group| (group.mentors.count == mentor_count && group.students.count == mentee_count)}.count > 0
    @program.scraps.where(:ref_obj_id => group_ids, :ref_obj_type => Group.to_s).destroy_all
    @program.groups.where(:id => group_ids).destroy_all
    populate_group_mentoring(@program, group_count, mentor_count, mentee_count)
    copy_group_permissions(group_ids)
  end
end