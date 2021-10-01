class ArticlesController < ApplicationController

  skip_action_callbacks_for_autocomplete :only => [:auto_complete_for_title]

  before_action :load_article, :except => [:auto_complete_for_title]
  before_action :load_all_tags, :only => [:new, :edit, :create, :update]
  before_action :handle_chrome_issue, only: :show
  before_action :add_custom_parameters_for_newrelic, :only => [:index]

  allow :user => [:can_write_article?], :only => [:new, :create]
  allow :user => [:can_view_articles?], :only => [:index, :show]
  allow :exec => :check_managed_or_authored, :only => [:edit, :update, :destroy]
  allow :exec => "@article.published?", :only => [:show]
  allow :exec => "@current_program.articles_enabled?", :except => [:auto_complete_for_title]

  def index
    @search_query = params[:search]
    @sort_field = params[:sort] || Article::DEFAULT_SORT_FIELD
    @sort_order = params[:order] || "desc"

    @program_labels_with_count = get_labels_and_count(@current_program.id)
    @all_label_count = Article.joins(:article_content, :publications).where(:article_contents => {:status => ArticleContent::Status::PUBLISHED}, :article_publications => {:program_id => @current_program.id}).count
    @label = ActsAsTaggableOn::Tag.find_by(name: params[:label]) if params[:label]

    @articles = Article.get_es_articles(@search_query, make_search_options(@sort_field, @sort_order, params[:page]))
    @comments_count_hash = Article::Publication.where(article_id: @articles.collect(&:id), program_id: current_program.id).joins(:comments).group("article_publications.article_id").count
  end

  def show
    @article.hit! unless wob_member.authored?(@article)
    @related_articles = @article.related(@current_program)
    @comments_count = @article_publication.comments.size

    track_activity_for_ei(EngagementIndex::Activity::VIEW_ARTICLE, {context_object: @article.title})

    if @article.type == ArticleContent::Type::LIST
      prepare_book_presenters(@article)
      @showing_web_thumbnail = true if @article.list_items.select {|item| item.type_string == "SiteListItem"}.any?
    end

    @back_link = {label: "feature.flag.header.Flags".translate, link: flags_path} if params[:from_flags] == "true"
  end

  #### Only admins or mentors
  def new
    if params[:type]
      @article = @current_organization.articles.new
      @article.build_article_content(:type => params[:type])
      @back_link = {:label => 'feature.article.header.articles'.translate(:articles => _Articles), :link => articles_path}
      render :action => "new_#{params[:type]}"
    end
  end

  # A call is to either save draft or publish a new article
  def create
    article_params = get_article_params(:create)
    article_params[:author] = wob_member
    article_params[:organization] = @current_organization
    user_and_sanitization_version = {current_user: current_user, current_member: current_member, sanitization_version: @current_organization.security_setting.sanitization_version}
    article_params[:article_content].merge!(user_and_sanitization_version)
    unless handle_article_creation(article_params)
      # Failure, take user to edit page with with error message
      handle_error_flash
      render action: "new_#{@article.type}"
    end
  rescue VirusError
    flash[:error] = "flash_message.announcement_flash.virus_present".translate
    redirect_to new_article_path(type: ArticleContent::Type::UPLOAD_ARTICLE) 
  end

  #### Only admins or owners
  def edit
    @is_edit = true
    handle_error_flash
    @back_link = {label: 'feature.article.header.articles'.translate(articles: _Articles), link: articles_path}
    render action: "new_#{@article.type}"
  end

  def update
    assign_user_and_sanitization_version(@article.article_content)
    handle_article_update(get_article_params(:update))
  rescue VirusError
    flash.now[:error] = "flash_message.announcement_flash.virus_present".translate
    @article.reload unless @article.new_record?
    edit()
  end

  def destroy
    Flag.set_status_as_deleted(@article, current_user, Time.now)
    @article = Article.includes(:publications => [:comments => [:flags, :recent_activities]]).find(@article.id)
    @article.destroy

    article_or_list = article_or_list(@article)
    if @article.draft?
      flash[:notice] = "flash_message.article.draft_discarded".translate
      redirect_to member_path(wob_member, :tab => 'articles')
    else
      flash[:notice] = "flash_message.article.deleted".translate(article_or_list: article_or_list)
      redirect_to articles_path
    end
  end

  # Rate an article
  def rate
    if @article.rated_by_user?(wob_member)
      @article.unmark_as_helpful!(wob_member)
    else
      @article.mark_as_helpful!(wob_member)
      track_activity_for_ei(EngagementIndex::Activity::LIKE_ARTICLE, {context_object: @article.title})
    end
    @article.reload
    redirect_to article_path_with_verification(@article) unless request.xhr?
    head :ok
  end

  def new_list_item
    @list_item_type = params[:type]
    @new_list_item = params[:type].classify.constantize_only(ArticleListItem.valid_types_as_strings).new
    render :layout => false
  end

  def auto_complete_for_title
    if params[:title]
      escaped_title = CGI::escape(params[:title])
      # Do a wildcard search on the title
      #
      # Note: The ECS search is strange:
      #   *ajax design patter* returns "Ajax Design Patterns"
      #   *ajax design patterns* does not
      amazon_res = Amazon::Ecs.item_search(nil, {:response_group => 'Small', :power => "title:*#{escaped_title}*"})
      @titles = amazon_res.items.collect {|item| item.get("ItemAttributes/Title")}
    else
      @titles = []
    end
    render json: @titles
  end
  #### Only admins or owners

  protected

  #
  # On success, setup flash and redirect user to proper page. On failure
  # return false. The caller (ArticlesController#create) will render the
  # edit page.
  #
  def handle_article_creation(article_params)
    requested_status = params[:article][:article_content][:status]
    @article, success = Article.create_draft(article_params)

    # Even the draft cannot be saved. Announce failure.
    return false if not success
    article_or_list = article_or_list(@article)
    case requested_status.to_i
    when ArticleContent::Status::PUBLISHED # publish if needed
      if @article.publish(get_programs_to_publish_to)
        flash[:notice] = "flash_message.article.published".translate(article_or_list: article_or_list)
        redirect_to article_path_with_verification(@article)
      else
        # Can't publish article. Announce failure.
        # Set this to reflect the fact that the draft has been saved.
        @article.article_content.status = ArticleContent::Status::DRAFT
        return false
      end
    else # if publish not necessary, take the user to edit page.
      flash[:notice] = "flash_message.article.draft_saved".translate(article_or_list: article_or_list)
      redirect_to edit_article_path(@article)
    end

    return true
  end

  def handle_article_update(article_params)    
    if @article.draft?
      case params[:article][:article_content][:status].to_i
      when ArticleContent::Status::DRAFT
        # Update the draft and return
        handle_save_draft(article_params)
      when ArticleContent::Status::PUBLISHED
        # Update the draft, publish the article and return
        handle_publish_draft(article_params)
      else
        raise "activerecord.custom_errors.article.invalid_update_status".translate
      end
    elsif @article.published?
      # Update the article
      handle_published_article_update(article_params)
    end
  end

  def handle_save_draft(article_params)
    if update_article_content(article_params)
      flash[:notice] = "flash_message.article.draft_saved".translate(article_or_list: article_or_list(@article))
      redirect_to(edit_article_path(@article))
    else
      edit()
    end
  end

  def handle_publish_draft(article_params)
    if update_article_content(article_params) && @article.publish(get_programs_to_publish_to)
      flash[:notice] = "flash_message.article.published".translate(article_or_list: article_or_list(@article))
      redirect_to article_path_with_verification(@article)
    else
      edit()
    end
  end

  def handle_published_article_update(article_params)
    if update_article_content(article_params)
      flash[:notice] = "flash_message.article.published".translate(article_or_list: article_or_list(@article))
      redirect_to article_path_with_verification(@article)
    else
      edit()
    end
  end

  def update_article_content(article_params)
    article_params = article_params[:article_content]
    article_params[:existing_listitem_attributes] ||= {}
    return @article.article_content.update_attributes(article_params)
  end

  def make_search_options(sort_field, sort_order, page_no)
    filter_options = {"publications.program_id" => @current_program.id}
    filter_options["article_content.labels.id"] = @label.id if @label
    sort_options = {sort_field => sort_order}
    sort_options[Article::DEFAULT_SORT_FIELD] = sort_order unless sort_field.to_s == Article::DEFAULT_SORT_FIELD

    {
      page: (page_no || 1), per_page: Article.per_page, filter: filter_options, sort: sort_options,
      includes: [article_content: [:labels, :list_items], author: [:profile_picture, users: :roles]]
    }
  end

  def load_article
    if params[:id]
      @article = @current_organization.articles.find(params[:id])
      if @article.published?
        @article = @current_program.articles.find(params[:id])
        @article_publication = @article.get_publication(@current_program)
      end
    end
  end

  def prepare_book_presenters(article)
    article.list_items.select {|item| item.type_string == "BookListItem"}.each do |item|
      item.presenter ||= BookListItemPresenter.new(item) unless item.content.blank?
    end
  end

  def load_all_tags
    @tag_names = Article.published_labels(@current_organization.program_ids).pluck("tags.name").uniq.join(',')
  end

  # Extracts the programs from the params
  def get_programs_to_publish_to
    prog_to_publish_to = params[:article][:publish_to]
    prog_to_publish_to = [@current_program.id] if prog_to_publish_to.nil?

		Program.find((prog_to_publish_to || "").split(","))
  end

  #
  # Returns whether the current user can manage articles or if the member
  # is the author.
  #
  def check_managed_or_authored
    current_user.can_manage_articles? || wob_member.authored?(@article)
  end

  private

  def get_article_params(action)
    if params[:article].present?
      return params[:article].permit([Article::MASS_UPDATE_ATTRIBUTES[action]]).tap do |whitelisted|
        if params[:article][:article_content][:new_listitem_attributes].present?
          whitelisted[:article_content][:new_listitem_attributes] = permit_internal_attributes(params[:article][:article_content][:new_listitem_attributes], [:type_string, :content, :description])
        end
        if params[:article][:article_content][:label_list].present?
          whitelisted[:article_content][:label_list] = params[:article][:article_content][:label_list]
        end
        if params[:article][:article_content][:existing_listitem_attributes].present?
          whitelisted[:article_content][:existing_listitem_attributes] = permit_internal_attributes(params[:article][:article_content][:existing_listitem_attributes], [:type_string, :content, :description])
        end
      end
    else
      {}
    end
  end

  def get_labels_and_count(program_id)
    Article.published_labels(program_id).group("tags.name").order("LOWER(tags.name) ASC").count
  end

  def article_or_list(article)
    article.list? ? "feature.article.content.list".translate : _article
  end

  def verification_token(method)
    method == :get ? session.delete("_verification_token") : (session["_verification_token"] ||= ((78364164096 + rand(2742745743359)).to_s(36)))
  end

  def article_path_with_verification(article, options = {})
    article_path(article, options.merge({verify: verification_token(:set)}))
  end

  def handle_chrome_issue
    response.headers['X-XSS-Protection'] = "0" if params[:verify].present? && params[:verify].eql?(verification_token(:get)) && (browser.chrome? || browser.safari?)
  end

  def handle_error_flash
    errors = @article.article_content.errors
    if !errors.messages.blank?
      if errors[:attachment_content_type].presence || errors[:attachment_file_size].presence
        flash[:error] = errors.full_messages.to_sentence.presence
        @article.reload unless @article.new_record?
      end
    end
  end
end
