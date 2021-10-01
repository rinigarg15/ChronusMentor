class ArticlePopulator < PopulatorTask

  def patch(options = {})
    member_ids = @organization.members.active.pluck(:id)
    articles_hsh = get_children_hash(@organization, @options[:args]["model"]||@node, @foreign_key, member_ids)
    process_patch(member_ids, articles_hsh) 
  end

  def add_articles(author_ids, articles_count, options = {})
    member_to_program_id_cache = {}
    authors = Member.active.where(id: author_ids).includes(:users).all
    authors.each{|author| member_to_program_id_cache[author.id] = author.users[0].try(:program_id) }
    self.class.benchmark_wrapper "Articles" do
      organization = options[:organization]
      organization_id = organization.id
      time_bound1 = organization.created_at
      time_bound2 = time_bound1 + 10.days
      time_bound3 = time_bound2 + 5.days
      all_tag_ids = ActsAsTaggableOn::Tag.where("name like 'perfv3_%'").pluck(:id)
      temp_author_ids = author_ids.dup
      labels_counts_sample_space = ([1]*99 + [2]*100 + [30])
      Article.populate(articles_count * author_ids.size, :per_query => 10_000) do |article|
        temp_author_ids = author_ids.dup if temp_author_ids.empty?
        article.view_count = 20..100
        article.helpful_count = 20..100
        article_author_id = temp_author_ids.shift
        article.author_id = article_author_id
        article.organization_id = organization_id
        article.created_at = time_bound1..time_bound2
        ArticleContent.populate 1 do |article_content|
          article_content.title = Populator.words(3..6)
          article_content.type = ArticleContent::Type.all - [ArticleContent::Type::UPLOAD_ARTICLE]
          set_article_content!(article_content)
          article_content.created_at = article.created_at
          article_content.status = Array([ArticleContent::Status::PUBLISHED]*3 + [ArticleContent::Status::DRAFT])
          article_content.published_at = (article_content.status == ArticleContent::Status::PUBLISHED) ? time_bound2..time_bound3 : nil
          article.article_content_id = article_content.id
          create_tags!(ArticleContent, article_content, "labels", labels_counts_sample_space.sample, all_tag_ids)
          if member_to_program_id_cache[article_author_id]
            Article::Publication.populate 1 do |publication|
              publication.program_id = member_to_program_id_cache[article_author_id]
              publication.article_id = article.id
            end
          end
        end
        self.dot
      end
      organization.programs.each do |program|
        user_ids = program.users.active.where(:member_id => author_ids).pluck(:id)
        populate_activity(program, user_ids, ActivityLog::Activity::ARTICLE_VISIT, 1)
      end
      self.class.display_populated_count(articles_count * author_ids.size, "Articles")
    end
  end

  def remove_articles(author_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Articles................" do
      organization = options[:organization]
      article_ids = organization.articles.where(:author_id => author_ids).select([:id, :author_id]).group_by(&:author_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      organization.articles.where(:id => article_ids).destroy_all
      self.class.display_deleted_count(count * author_ids.size, "Articles")
    end
  end

  def set_article_content!(article_content)
    article_type = article_content.type
    case article_type
    when ArticleContent::Type::TEXT
      article_content.body = Populator.sentences(3..6)
    when ArticleContent::Type::MEDIA
      article_content.body = Populator.sentences(3..6)
      article_content.embed_code = "https://www.youtube.com/watch?v=L9dC8BQnkw0"
    when ArticleContent::Type::LIST
      ArticleListItem.populate 5..10 do |article_list_item|
        article_list_item.type = [SiteListItem.to_s, BookListItem.to_s]
        article_list_item.content = ((article_list_item.type == BookListItem.to_s) ? "A Game of Thrones (A Song of Ice and Fire, Book 1)" : "http://www.railstips.org/")
        article_list_item.description = Populator.sentences(3..6)
        article_list_item.article_content_id = article_content.id
      end
    end
  end
end