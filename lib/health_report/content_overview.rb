module HealthReport
  class ContentOverview < CumulativeReport
    ITEM_HASH = {
      :resources => {name: "resources", threshold: 4, minimum: 0, maximum: 10},
      :articles => {name: "articles", threshold: 4, minimum: 0, maximum: 10},
      :forums => {name: "forum_posts", threshold: 4, minimum: 0, maximum: 10},
      :questions => {name: "question_and_answers", threshold: 4, minimum: 0, maximum: 10},
      :comments => {name: "comments", threshold: 4, minimum: 0, maximum: 10}
    }

    attr_accessor :program, :history_metrics, :percent_metrics

    cumulative_metric :percent_metrics

    def initialize(program)
      self.program = program
      self.history_metrics = {}
      self.percent_metrics = {}
      ITEM_HASH.each do |item, options|
        self.history_metrics[item] = HistoryMetric.new
        self.percent_metrics[item] = PercentMetric.new(options[:threshold], options)
      end
    end

    def item_name(item)
      ITEM_HASH[item][:name]
    end

    # Contents that are enabled for this program.
    def available_contents
      return @available_contents if @available_contents

      @available_contents = []
      enabled_features = self.program.enabled_features
      @available_contents << :resources if enabled_features.include?(FeatureName::RESOURCES)
      @available_contents << :articles if enabled_features.include?(FeatureName::ARTICLES)
      @available_contents << :forums if self.program.forums.program_forums.any? && enabled_features.include?(FeatureName::FORUMS)
      @available_contents << :questions if enabled_features.include?(FeatureName::ANSWERS)
      @available_contents << :comments if enabled_features.include?(FeatureName::ARTICLES)
      @available_contents
    end

    def has_content?(content_name)
      available_contents.include?(content_name)
    end

    def compute
      p = self.program
      last_month = 1.month.ago
      curr_count_hash = Hash.new(0)
      last_month_count_hash = Hash.new(0)
      if has_content?(:resources)
        member_ids = p.users.collect(&:member_id)
        resource_ids = p.resource_publications.collect(&:resource_id)
        ratings = Rating.where(rateable_id: resource_ids,  rateable_type: "Resource",  user_id: member_ids, rating: Resource::RatingType::HELPFUL)
        curr_count_hash[:resources] = ratings.count
        last_month_count_hash[:resources] = ratings.where("ratings.created_at > ?", 1.month.ago).count
      end
      if has_content?(:articles)
        curr_count_hash[:articles] = p.articles.published.count
        last_month_count_hash[:articles] = p.articles.published.where("articles.created_at > ?", last_month).count
      end
      if has_content?(:forums)
        program_forum_ids = p.forums.program_forums.pluck(:id)
        topics_in_program_forums = p.topics.where(forum_id: program_forum_ids).select(:id, :posts_count)
        posts_in_program_forums = p.posts.where(topic_id: topics_in_program_forums.collect(&:id))
        curr_count_hash[:forums] = topics_in_program_forums.sum(:posts_count)
        last_month_count_hash[:forums] = posts_in_program_forums.where("posts.created_at > ?", last_month).count
      end
      if has_content?(:questions)
        curr_count_hash[:questions] = p.qa_questions.count + p.qa_answers.count
        last_month_count_hash[:questions] = p.qa_questions.where("created_at > ?", last_month).count + p.qa_answers.where("qa_answers.created_at > ?", last_month).count
      end

      if has_content?(:comments)
        curr_count_hash[:comments] = p.comments.count
        last_month_count_hash[:comments] = p.comments.where("comments.created_at > ?", last_month).count
      end
      ITEM_HASH.keys.each do |item|
        self.percent_metrics[item].update_metric(curr_count_hash[item])
        self.history_metrics[item].update_metric(curr_count_hash[item], last_month_count_hash[item])
      end
    end
  end
end