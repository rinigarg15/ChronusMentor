class ArticleCommentPopulator < PopulatorTask

  def patch(options = {})
    article_publication_ids = @program.article_publications.pluck(:id)
    article_comments_hsh = get_children_hash(@program, "comment", "article_publication_id", article_publication_ids)
    process_patch(article_publication_ids, article_comments_hsh) 
  end

  def add_article_comments(article_publication_ids, count, options = {})
    self.class.benchmark_wrapper "Article Comments" do
      program = options[:program]
      user_ids = program.users.active.pluck(:id)
      temp_user_ids = user_ids.dup
      temp_publication_ids = article_publication_ids * count
      Comment.populate(article_publication_ids.size * count, :per_query => 10_000) do |comment|
        temp_user_ids = user_ids.dup if temp_user_ids.blank?
        comment.article_publication_id = temp_publication_ids.shift
        comment.user_id = temp_user_ids.shift
        comment.body = Populator.sentences(3..5)
        self.dot
      end
      self.class.display_populated_count(count * article_publication_ids.size, "Article Comments")
    end
  end

  def remove_article_comments(article_publication_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Article Comments................" do
      program = options[:program]
      article_comment_ids = program.comments.where(:article_publication_id => article_publication_ids).select("comments.id, comments.article_publication_id").group_by(&:article_publication_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.comments.where(:id => article_comment_ids).destroy_all
      self.class.display_deleted_count(count * article_publication_ids.size, "Article Comments")
    end
  end
end