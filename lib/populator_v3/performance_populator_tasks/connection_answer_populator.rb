class ConnectionAnswerPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    group_ids = @program.groups.pluck(:id)
    connection_answers_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, group_ids)
    process_patch(group_ids, connection_answers_hsh) 
  end

  def add_connection_answers(group_ids, count, options = {})
    program = options[:program]
    connection_questions = program.connection_questions.where("question_type != #{CommonQuestion::Type::FILE}").to_a
    return if connection_questions.blank?
    self.class.benchmark_wrapper "Connection Answers" do
      temp_questions = connection_questions.dup
      temp_group_ids = group_ids * count
      Connection::Answer.populate(group_ids.count * count, :per_query => 10_000) do |connection_answer|
        temp_questions = connection_questions.dup if temp_questions.blank?
        connection_question = temp_questions.shift
        connection_answer.type = Connection::Answer.to_s
        connection_answer.common_question_id = connection_question.id
        connection_answer.group_id = temp_group_ids.shift
        set_common_answer_text!(connection_question, connection_answer)
        self.dot
      end
      self.class.display_populated_count(group_ids.size * count, "Connection Answers")
    end
  end

  def remove_connection_answers(group_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Connection Answer................" do
      connection_answer_ids = Connection::Answer.where(:group_id => group_ids).select([:id, :group_id]).group_by(&:group_id).to_a.map{|a| a[1].last(count)}.flatten.collect(&:id)
      Connection::Answer.where(:id => connection_answer_ids).destroy_all
      self.class.display_deleted_count(group_ids.size * count, "Connection Answers")
    end
  end
end