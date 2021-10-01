class MentoringModelTaskCommentPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    mentoring_model_task_ids = @program.mentoring_model_tasks.pluck(:id)
    mentoring_models_task_comment_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, mentoring_model_task_ids)
    process_patch(mentoring_model_task_ids, mentoring_models_task_comment_hsh)
  end

  def add_mentoring_model_task_comments(task_ids, task_comments_count, options)
    tasks = MentoringModel::Task.includes([group: [:program, :members]]).where(id: task_ids).select([:group_id, :id])
    self.class.benchmark_wrapper "Task Comments" do
      MentoringModel::Task::Comment.populate task_comments_count * task_ids.size do |task_comment|
        task = tasks.last
        tasks = tasks.rotate
        task_comment.program_id = task.group.program.id
        task_comment.sender_id = task.group.members.pluck(:id).sample
        task_comment.content = Populator.sentences(2..6)
        task_comment.mentoring_model_task_id = task.id
        task_comment.created_at = Time.now + rand(1..20).days
        self.dot
      end
      self.class.display_populated_count(task_ids.size * task_comments_count, "Mentoring Model Task Comment")
    end
  end

  def remove_mentoring_model_task_comments(mentoring_model_task_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Task Comments................" do
      program = options[:program]
      mentoring_model_task_comments_ids = MentoringModel::Task::Comment.where(:mentoring_model_task_id => mentoring_model_task_ids).select([:id, :mentoring_model_task_id]).group_by(&:mentoring_model_task_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      MentoringModel::Task::Comment.where(:id => mentoring_model_task_comments_ids).destroy_all
      self.class.display_deleted_count(mentoring_model_task_ids.size * count, "Mentoring Model Task Comment")
    end
  end
end