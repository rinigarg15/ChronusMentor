class ArticleObserver < ActiveRecord::Observer

  def after_create(article)
    # Create an RA for the admins and the author
    after_publish(article) if article.published?
  end

  def after_update(article)
    # Create an RA for the the author and the rater on rating change
    if article.saved_change_to_helpful_count? && (article.helpful_count == (article.helpful_count_before_last_save.to_i + 1))
      create_article_ra(
        article,
        RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL,
        RecentActivityConstants::Target::USER,
        :member => article.rated_by,
        :for => article.author
      )
    end
  end

  def after_destroy(article)
    art_content = article.article_content.reload
    art_content.destroy if art_content && art_content.articles.empty?
  end

  # Creates an RA published to the param +programs+
  #
  # Params:
  # <tt>programs</tt> : Programs in which the article is newly published. Defaults to nil, in which case
  # a new RA is created in just the newly published programs
  #
  def after_publish(article, added_programs = nil, removed_programs = nil)
    # Callbacks wont happen on the dependent destroy of children.
    # So, we have to manually destroy the program activites of the article publish in removed programs
    if removed_programs.present?
      activities = ProgramActivity.joins(:activity).where(recent_activities: {ref_obj_type: Article.name, ref_obj_id: article.id}, program_id: removed_programs.collect(&:id))
      activities.destroy_all
    end

    if added_programs.nil? || !added_programs.blank?
      create_article_ra(article, RecentActivityConstants::Type::ARTICLE_CREATION, RecentActivityConstants::Target::ALL, :programs => added_programs)
    end
  end

  protected

  def create_article_ra(article, event, target, opts = {})
    member = opts[:member] || article.author
    for_member = ((target == RecentActivityConstants::Target::USER) ? (opts[:for] || article.author) : nil)

    # The RA creation must create the PA only in programs the +member+ and
    # +article+ is common to.
    # & performs the intersection between two Ruby arrays.
    programs_to_create_ra = opts[:programs] || article.published_programs
    programs_to_create_ra &= member.active_programs

    RecentActivity.create!(
      :member => member,
      :ref_obj => article,
      :programs => programs_to_create_ra,
      :action_type => event,
      :for => for_member,
      :target => target
    )
  end
end
