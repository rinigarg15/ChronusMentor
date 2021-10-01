class FlagPopulator < PopulatorTask

  def patch(options = {})
    program_ids = @organization.programs.pluck(:id)
    flags_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, flags_hsh) 
  end

  def add_flags(program_ids, count, options = {})
    self.class.benchmark_wrapper "Flags" do
      programs = Program.where(:id => program_ids)
      programs.each do |program|
        article_comment_ids = program.article_publications.collect(&:comments).flatten.collect(&:id)
        article_ids = program.articles.pluck(:id)
        post_ids = program.forums.collect(&:topics).flatten.collect(&:posts).flatten.collect(&:id)
        qa_question_ids = program.qa_questions.pluck(:id)
        qa_answer_ids = program.qa_answers.pluck(:id)
        user_ids = program.users.active.pluck(:id)
        admin_user_ids = program.admin_users.pluck(:id)
        temp_user_ids = user_ids.dup
        content_type = ["Comment", "Article", "Post", "QaQuestion", "QaAnswer"]
        status = [Flag::Status::UNRESOLVED ,Flag::Status::DELETED , Flag::Status::EDITED ,Flag::Status::ALLOWED]
        Flag.populate(count, :per_query => 10_000) do |flag|
          temp_user_ids = user_ids.dup if temp_user_ids.blank?
          flag.user_id = temp_user_ids.shift
          flag.content_type = content_type.sample
          flag.content_id = article_comment_ids.sample if flag.content_type == "Comment"
          flag.content_id = article_ids.sample if flag.content_type == "Article"
          flag.content_id = post_ids.sample if flag.content_type == "Post"
          flag.content_id = qa_question_ids.sample if flag.content_type == "QaQuestion"
          flag.content_id = qa_answer_ids.sample if flag.content_type == "QaAnswer"
          flag.status = status.sample
          flag.resolver_id = admin_user_ids.sample if flag.status != Flag::Status::UNRESOLVED
          flag.program_id = program.id
          flag.created_at = rand(2..90).days.ago
          flag.resolved_at = flag.created_at + 1.day if flag.status != Flag::Status::UNRESOLVED
          flag.reason = Populator.words(5..10)
          self.dot
        end
      end
      self.class.display_populated_count(program_ids.size * count, "Flags")
    end
  end

  def remove_flags(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Flag......." do
      flag_ids = Flag.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Flag.where(:id => flag_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Flags")
    end
  end
end