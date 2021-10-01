# == Schema Information
#
# Table name: articles
#
#  id                 :integer          not null, primary key
#  view_count         :integer          default(0)
#  helpful_count      :integer          default(0)
#  author_id          :integer
#  organization_id    :integer
#  delta              :boolean
#  created_at         :datetime
#  updated_at         :datetime
#  article_content_id :integer
#

class Article < ActiveRecord::Base
  include ViewCount
  acts_as_rateable
  include ArticleElasticsearchSettings
  include ArticleElasticsearchQueries

  ES_SCOPE = "published"

  HELPFUL = 1
  NOT_HELPFUL = -1
  MAX_RELATED_ARTICLES_TO_SHOW = 5
  DEFAULT_SORT_FIELD = 'created_at'
  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  belongs_to  :article_content
  belongs_to  :author, :class_name => 'Member'

  belongs_to_organization :foreign_key => 'organization_id'

  has_many  :publications,
            :class_name => "Article::Publication",
            :dependent => :destroy,
            :inverse_of => :article

  has_many  :published_programs,
            :class_name => 'Program',
            :through => :publications,
            :source => :program

  has_many  :recent_activities,
            :as => :ref_obj,
            :dependent => :destroy

  has_many  :pending_notifications,
            :as => :ref_obj,
            :dependent => :destroy

  has_many  :flags,
            :as => :content,
            :dependent => :nullify

  #-----------------------------------------------------------------------------
  # ATTRIBUTES
  #-----------------------------------------------------------------------------

  # attr_protected  :author, :organization, :published_programs
  attr_accessor   :rated_by, :just_published

  delegate  :title,
            :body,
            :embed_code,
            :attachment,
            :type,
            :article_list_items,
            :labels,
            :label_list,
            :label_list=,
            :list_items=,
            :list_items,
            :existing_listitem_attributes=,
            :new_listitem_attributes=,
            :list?,
            :media?,
            :uploaded_content?,
            :published?,
            :draft?,
            :published_once?,
            :status,
            :to => :article_content

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates_presence_of :author, :organization, :article_content
  validates_presence_of :published_programs, :unless => Proc.new{ :article_content && :draft?}
  validates_associated  :article_content

  #-----------------------------------------------------------------------------
  # SCOPES
  #-----------------------------------------------------------------------------

  scope :published, -> {
    joins(:article_content).where({:article_contents => { :status => ArticleContent::Status::PUBLISHED }})
  }

  scope :drafts, -> {
    joins(:article_content).where({:article_contents => { :status => ArticleContent::Status::DRAFT }})
  }

  # Scopes to the articles published in the given program.
  scope :published_in, ->(program) {
    joins(:publications).where({:article_publications => {:program_id => program}})
  }

  scope :in_organization, ->(organizations) {
    where({:organization_id => organizations})
  }
  scope :created_in_date_range, Proc.new { |date_range| where(created_at: date_range) }

  MASS_UPDATE_ATTRIBUTES = {
   :create => [:article_content => [:title, :type, :body, :attachment, :status, :embed_code, :label_list]],
   :update => [:article_content => [:title, :type, :body, :attachment, :status, :embed_code, :label_list]]
  }

  # XXX Remove this after migration
  # To prevent 'type' from being interpreted as STI column.
  self.inheritance_column = 'type__'

  def self.recent(since)
    where(['articles.created_at > ?', since])
  end

  ### Elasticsearch Indexing Methods ####
  def role_ids
    Role.where(program_id: Article::Publication.where(article_id: self.id).pluck(:program_id)).pluck(:id)
  end
  #######################################

  def mark_as_helpful!(member)
    return unless can_be_rated_by?(member)

    self.ratings << Rating.new(:rating => 1, :member => member)
    self.rated_by = member
    self.helpful_count += 1
    self.save!
  end

  def unmark_as_helpful!(member)
    user_rating = self.find_user_rating(member)
    return if user_rating.blank?

    user_rating.destroy
    self.helpful_count -= 1
    self.save!
  end

  def related(program)
    search_options = {
      page: 1,
      per_page: MAX_RELATED_ARTICLES_TO_SHOW,
      sort: {_score: ElasticsearchConstants::SortOrder::DESC, id: ElasticsearchConstants::SortOrder::DESC},
      fields: ["article_content.labels.name.language_*", "article_content.title.language_*", "author.name_only"],
      boost_hash: {"article_content.labels.name.language_*" => 0.6, "article_content.title.language_*" => 0.3, "author.name_only" => 0.1},
      filter: {"publications.program_id": program.id},
      fetch_related_articles: true,
      must_not_filter: {id: self.id},
      includes: [:article_content]
    }
    search_text = [self.title, self.author.name(name_only: true), self.label_list].flatten.select(&:present?).join(" ")
    Article.get_es_articles(search_text, search_options)
  end

  # Returns the +Publication+ of this article in the given program.
  def get_publication(program)
    self.publications.in_program(program).first
  end

	# Create an article draft
  def self.create_draft(article_params)
    organization = article_params[:organization]
    member = article_params[:author]

    # Force the draft status
    article_params[:article_content][:status] = ArticleContent::Status::DRAFT

    article = organization.articles.new
    article.author = member
    new_listitem_attributes = article_params[:article_content].delete(:new_listitem_attributes)
    article.build_article_content(article_params[:article_content])
    article.article_content.new_listitem_attributes = new_listitem_attributes if new_listitem_attributes.present?

    if article.save
      return [article, true]
    else
      return [article, false]
    end
  end

  # Returns the 'real' article status rather than the value stored on the
  # current object. We want this because we want to find out the 'real_status'
  # of an object without reloading the object.
  def real_status
    self.new_record? ?
      ArticleContent::Status::DRAFT :
      ArticleContent.find(self.article_content_id).status
  end

  #
  # Publish the article in the programs given in the array *programs_to_publish* and
  # unpublish from the organizations in the array *organizations_to_unpublish*
  #
  def publish(program_ids_to_publish = [])
    ActiveRecord::Base.transaction do
      if program_ids_to_publish.empty?
        return self.destroy
      end

      programs_to_publish = Program.includes(:translations, :organization => :auth_configs).where(id: program_ids_to_publish)
      self.article_content.status = ArticleContent::Status::PUBLISHED
      self.article_content.published_at = Time.now

      # If the article content is successfully saved, publish in other organizations
      # and programs
      if self.article_content.save
        # We already have +this+ Article created in this organization. Just
        # create the publications.
        old_programs = self.published_programs.clone
        added_programs = programs_to_publish - old_programs
        removed_programs = old_programs - programs_to_publish

        #Automatic deletion of join models is direct, no destroy callbacks are triggered.
        #refer http://guides.rubyonrails.org/association_basics.html
        #So, we destroy them here.
        ActiveRecord::Base.transaction do
          publication_records = self.publications.where(program_id: removed_programs)
          publication_records.each do |pub_rec|
            pub_rec.destroy
          end
        end
        self.published_programs = programs_to_publish

        # The Article Observer creates an RA once the article is published
        ArticleObserver.instance.after_publish(self, added_programs, removed_programs)

        return true
      else
        # The article content is not saveable; return false.
        return false
      end
    end
  end

  def self.published_labels(program_ids=[])
    ActsAsTaggableOn::Tag.joins(:taggings)
      .joins("INNER JOIN article_contents ON taggings.taggable_id = article_contents.id AND taggings.taggable_type = '#{ArticleContent.name}' ")
      .joins("INNER JOIN articles ON articles.article_content_id = article_contents.id")
      .joins("INNER JOIN article_publications ON article_publications.article_id = articles.id")
      .where( :article_publications => {:program_id => program_ids},
              :article_contents => {:status => ArticleContent::Status::PUBLISHED})
  end

  def self.get_article_ids_published_in_program(program_ids)
    article_ids = Article::Publication.where(program_id: program_ids).pluck(:article_id)
    Article.where(id: article_ids).published.pluck(:id)
  end

  private

  def can_be_rated_by?(member)
    # The rating member should belong to the same organization as the article
    (self.organization == member.organization) &&
    # The rating user has not already rated the article
    !rated_by_user?(member)
  end
end
