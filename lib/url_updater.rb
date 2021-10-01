# Updated on August 21, 2018
# Please check the 'test/fixtures/files/text_columns_so_far.yaml' before running this rake to check if any new text column is added to the database and missed to handle in url updater.
class UrlUpdater
  URL_UPDATER_USAGE = <<-USAGE
    URL_UPDATE_USAGE:
    bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [NEWDOMAIN=(newdomain)] [NEWSUBDOMAIN=(newsubdomain)] ([TOHTTP=true] | [TOHTTPS=true]) [ASSESS_ONLY=true] [CLONED_SOURCE_DB=(cloned source db)]
    ROOT_UPDATE_USAGE:
    bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [ROOT=(root)] [NEWROOT=(newroot)]
    CHANGE OLD IDS IN ORG USAGE:
    bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [NEWDOMAIN=(newdomain)] [NEWSUBDOMAIN=(newsubdomain)] [SOURCE_ENVIRONMENT=(source_environment)] [SOURCE_SEED=(source_seed)] [CHANGE_OLD_IDS=true]
    bundle exec rake common:url_updater:change_urls [DOMAIN=(domain)] [SUBDOMAIN=(subdomain)] [CHANGE_OLD_IDS=true]  [ASSESS_ONLY=true]
    ALL_URLS_UPDATE_USAGE(run both the commands below)
    bundle exec rake common:url_updater:change_urls URL_TO_CHANGE="s3.amazonaws.com/chronus-mentor-assets" NEW_URL="chronus-mentor-assets-backup/s3-us-west-1.amazonaws.com"
    bundle exec rake common:url_updater:change_urls URL_TO_CHANGE="chronus-mentor-assets.s3.amazonaws.com" NEW_URL="chronus-mentor-assets-backup/s3-us-west-1.amazonaws.com"
  USAGE
  HTTP_REGEX = /(src.{0,3}=.{0,3}|url[\(])(http:)([^ \'\"\)]*)/
  EMBED_MEDIA = /((?!src.{0,3}=.{0,3}|url[\(]))(http:)([^ \'\"\)]*)/
  COMMON_HTTPS_URLS = /(www.youtube.com)|(s3.amazonaws.com)|(google[\-]analytics.com)/
  CONNECTION_TIMEOUT = 5 #in seconds
  ROOT_REGEX = "([\/]p[\/][A-Za-z0-9\-]+)?"

  def initialize(options = {})
    begin
      @domain = options[:domain]
      @subdomain = options[:subdomain]
      root = options[:root]
      new_domain = options[:new_domain]
      new_subdomain = options[:new_subdomain]
      new_root = options[:new_root]
      base_url = @subdomain.present? ? "#{@subdomain}.#{@domain}" : @domain

      Common::RakeModule::Utils.establish_cloned_db_connection(options[:cloned_source_db])

      if root.present? && new_root.present?
        @url_present = "#{base_url}/p/#{root}"
        @url_change = "#{base_url}/p/#{new_root}"
      elsif options[:url_to_change] && options[:new_url]
        @url_present = options[:url_to_change]
        @url_change = options[:new_url]
      else
        @change_http_to_https = options[:to_https].present?
        @change_https_to_http = options[:to_http].present?
        @url_present = base_url
        @url_change = new_subdomain.present? ? "#{new_subdomain}.#{new_domain}" : new_domain
        @http_url = "http://#{@url_change}"
        @https_url = "https://#{@url_change}"
        @source_environment = options[:source_environment]
        @source_seed = options[:source_seed]
        @change_old_ids = options[:change_old_ids]
        @route_model_map = {"ck_attachments" => "Ckeditor::AttachmentFile", "ck_pictures" => "Ckeditor::Picture"}
      end
      @assess_only = options[:assess_only] || false
      if @change_old_ids
        @target_ids_hash = {}
        @change_old_ids_csv_file_path = "tmp/old_ids_updater_info_#{@subdomain}_#{@domain}.csv"
        @change_old_ids_csv = CSV.open(File.join(Rails.root, @change_old_ids_csv_file_path), 'w')
        @change_old_ids_csv <<  ["Model", "ID", "COLUMN", "URL_NOT_REPLACED"]
      end
      @es_reindex_hash = {}
      @skip_es_reindex = (@assess_only || @change_old_ids).present?
      @info = CSV.open("#{Rails.root}/tmp/url_updater_info_#{new_subdomain}_#{new_domain}.csv", 'w')
    rescue
      raise URL_UPDATER_USAGE
    end
  end

  def https_link_exists?(link)
    begin
      return true if link.match(COMMON_HTTPS_URLS).present?
      url = URI.parse(link)
      request = Net::HTTP.new(url.host, url.port)
      request.use_ssl = true
      request.open_timeout = CONNECTION_TIMEOUT
      response = request.get(url.path.to_s + "?" + url.query.to_s)
    rescue Exception
      #do nothing
    end
    response.present? && response.code.to_i == HttpConstants::SUCCESS
  end

  def change_urls(attribute, object, options = {})
    @old_ids_replacer_info =  [object.class.name, object.id, attribute] if @change_old_ids
    old_value = object.send(attribute)
    new_value = change_chronus_urls(old_value)
    new_value = change_non_chronus_urls(attribute, object, new_value) if @change_http_to_https
    new_value = change_non_chronus_urls(attribute, object, new_value, options[:embed_media]) if @change_http_to_https && options[:embed_media].present?
    if old_value != new_value
      puts "CHANGING_URL : #{object.class.name}, #{object.id}, #{attribute}"
      puts "OLD ::       #{old_value}"
      puts "NEW ::       #{new_value}"
      unless @assess_only
        unless object.class.translates? && object.class.translated_attribute_names.include?(attribute)
          object.update_columns(attribute.to_sym => new_value, skip_delta_indexing: true)
          collect_id_for_es_reindex(object)
        end
      end
    end
  end

  def get_es_model_name(object)
    return object.class.name if object.class.respond_to? :__elasticsearch__
    object.class.subclasses.first { |klass| klass.name if object.type == klass.name && klass.respond_to?(:__elasticsearch__) }
  end

  def collect_id_for_es_reindex(object)
    return if @skip_es_reindex
    es_model = get_es_model_name(object)
    return if es_model.blank?
    @es_reindex_hash[es_model] ||= []
    @es_reindex_hash[es_model] << object.id
  end

  def change_chronus_urls(value)
    return value if !value.present? || !value.include?(@url_present)
    value = value.gsub(@url_present, @url_change)
    value = match_url_patterns_and_replace_ids(value) if @change_old_ids
    if @change_https_to_http
      value = value.gsub(@https_url, @http_url) if value.include? @https_url
    elsif @change_http_to_https
      value = value.gsub(@http_url, @https_url) if value.include? @http_url
    end
    value
  end

  def get_target_id(model, source_id)
    source_audit_key = "#{@source_environment}_#{@source_seed}_#{source_id}"
    return @target_ids_hash[model.name][source_audit_key] if @target_ids_hash[model.name] && @target_ids_hash[model.name].has_key?(source_audit_key)
    target = model.find_by(source_audit_key: source_audit_key)
    @target_ids_hash[model.name] ||= {}
    @target_ids_hash[model.name][source_audit_key] = target.try(:id)
  end

  def match_url_patterns_and_replace_ids(value)
    visited_links = {}
    # collect all the urls in the text.
    links = URI.extract(value)
    links.each do |old_link|
      old_link = old_link.scan(/#{@url_change}.*\d+/).first
      next if old_link.blank? || visited_links[old_link].present?
      new_link = old_link.dup
      # counter to find the number of nested member routes. Ex: walkthru.chronus.com/groups/1/scraps/2 => ids should be replaced for 2 models groups & scraps.
      regex_counter = get_regex_substitution_count(old_link)
      regex_str = ""
      regex_counter.times do
        regex_str += "[\/](.+?)[\/](\\d+)"
      end
      # link can either be an org url or program url
      regex = Regexp.new(@url_change + ROOT_REGEX + regex_str)
      model_ids_map = old_link.scan(regex).flatten[1..-1] || []
      model_ids_map.each_slice(2) do |model_name, source_id|
        new_link = replace_source_id_with_target_id(model_name, source_id, new_link)
      end
      visited_links[old_link] = new_link
      if old_link != new_link
        value.gsub!(/#{old_link}(\D|$)/){|link| "#{new_link}#{$1}"}
      elsif !@url_verified
        # If link is unchanged check whether the mapping for the model name and route path needs to be added in route_model_map.
        puts "Unchanged Link: #{old_link}".red
        @change_old_ids_csv << (@old_ids_replacer_info + [old_link])
      end
    end
    value
  end

  def replace_source_id_with_target_id(model_name, source_id, new_link)
    begin
      model_class = @route_model_map.keys.include?(model_name) ? @route_model_map[model_name] : model_name.classify
      model = model_class.constantize
      raise unless model <= ActiveRecord::Base
      unless @assess_only
        target_id = get_target_id(model, source_id)
        new_link.gsub!("/#{model_name}/#{source_id}", "/#{model_name}/#{target_id}") if target_id.present?
      end
      @url_verified = true
    rescue
      @url_verified = false
      puts "No model found for name #{model_class}"
    end
    new_link
  end

  def get_regex_substitution_count(link)
    # link can either be an org url or program url
    resources = link.scan(/#{@url_change}#{ROOT_REGEX}(.*)/).flatten[1]
    slashes_count = resources.scan("/").size || 1
    ((slashes_count) / 2) || 1
  end

  # plain_embed_media = true = > Specifically written for article MEDIA CONTENT as the embed code can have it plainly as a url . But this in turn doesn't affect the viewing/serving of the material as it is taken care by JQuerys oembed.But also updating in database so as to ensure consistency
  def change_non_chronus_urls(attribute, object, value, plain_embed_media=false)
    return value if !value.present?
    regex = plain_embed_media ? EMBED_MEDIA : HTTP_REGEX
    return value if !value.match(regex)

    value.gsub(regex) do |http_link|
      if https_link_exists?("https:#{$3}")
        @info << [object.class.name, object.id, attribute,"Yes", "#{$1}https:#{$3}"]
        "#{$1}https:#{$3}"
      else
        @info << [object.class.name, object.id, attribute ,"No", "#{$1}#{$2}#{$3}"]
        "#{$1}#{$2}#{$3}"
      end
    end
  end

  def change_urls_for_objects(objects, column_names, options = {})
    objects.each do |object|
      column_names.each do |column|
        change_urls(column.to_sym, object, options)
      end
    end
  end

  def change_urls_for_objects_with_translations(model, column_names, objects, options = {})
    # Only parent model should use this method. Translated models should not be allowed.
    return if model.reflect_on_all_associations(:belongs_to).collect(&:name).include?(:globalized_model)
    change_urls_for_objects(objects, column_names, options)
    if model.respond_to? :translation_class
      translated_model = model.translation_class
      parent_model_id = translated_model.reflect_on_all_associations(:belongs_to).select{|assoc| assoc.name.to_s == "globalized_model"}[0].foreign_key
      translated_objects = translated_model.where(parent_model_id => objects.collect(&:id))
      translated_columns = model.translated_attribute_names & column_names
      if translated_columns.present?
        change_urls_for_objects(translated_objects, translated_columns, options)
      end
    end
  end

  def change_urls_for_models_associated_with_groups(group_ids)
    mentoring_model_tasks = MentoringModel::Task.where(group_id: group_ids)
    mentoring_model_goals = MentoringModel::Goal.where(group_id: group_ids)
    mentoring_model_milestones = MentoringModel::Milestone.where(group_id: group_ids)

    change_urls_for_objects_with_translations(MentoringModel::Task, [:description], mentoring_model_tasks)
    change_urls_for_objects_with_translations(MentoringModel::Goal, [:description], mentoring_model_goals)
    change_urls_for_objects_with_translations(MentoringModel::Milestone, [:description], mentoring_model_milestones)
  end

  def change_urls_for_models_associated_with_mentoring_model(mentoring_model)
    mentoring_model_task_templates = MentoringModel::TaskTemplate.where(mentoring_model_id: mentoring_model.id)
    mentoring_model_facilitation_templates = MentoringModel::FacilitationTemplate.where(mentoring_model_id: mentoring_model.id)
    mentoring_model_goal_templates = MentoringModel::GoalTemplate.where(mentoring_model_id: mentoring_model.id)
    mentoring_model_milestone_templates = MentoringModel::MilestoneTemplate.where(mentoring_model_id: mentoring_model.id)

    change_urls_for_objects_with_translations(MentoringModel::TaskTemplate, [:description], mentoring_model_task_templates)
    change_urls_for_objects_with_translations(MentoringModel::FacilitationTemplate, [:message], mentoring_model_facilitation_templates)
    change_urls_for_objects_with_translations(MentoringModel::GoalTemplate, [:description], mentoring_model_goal_templates)
    change_urls_for_objects_with_translations(MentoringModel::MilestoneTemplate, [:description], mentoring_model_milestone_templates)
  end

  def update_all_urls_in_db
    Organization.all.each do |organization|
      update_all_urls_of_an_organization(organization) if organization.active?
    end
  end

  def reindex_es_models
    return if @skip_es_reindex
    collect_dependent_es_models
    @es_reindex_hash.each do |model_name, ids|
      DelayedEsDocument.delayed_bulk_update_es_documents(model_name.constantize, ids)
    end
  end

  def collect_dependent_es_models
    @es_reindex_hash["ThreeSixty::SurveyAssessee"] = ThreeSixty::SurveyAssessee.where(three_sixty_survey_id: @es_reindex_hash["ThreeSixty::Survey"]).pluck(:id) if @es_reindex_hash["ThreeSixty::Survey"].present?
  end

  def update_all_urls_of_an_organization(organization = nil)
    Common::RakeModule::Utils.execute_task do
      organization ||= Common::RakeModule::Utils.fetch_programs_and_organization(@domain, @subdomain)[1]

      puts "==================================For website #{organization.url}========================================="
      organization_url = organization.url
      program_ids = organization.program_ids
      program_organization_ids = program_ids + [organization.id]
      abstract_programs = AbstractProgram.where(id: program_organization_ids)
      auth_configs = organization.auth_configs
      pages = Page.where(program_id: organization.id)
      resources = Resource.where(program_id: organization.id)
      mailer_templates = Mailer::Template.where(program_id: organization.id)
      mailer_widgets = Mailer::Widget.where(program_id: organization.id)
      articles = Article.where(organization_id: organization.id).select([:id, :article_content_id])
      article_contents = ArticleContent.where(:id => articles.pluck(:article_content_id))
      article_publications = Article::Publication.where(article_id: articles.pluck(:id))
      drafted_article_content_ids = article_contents.where(status: ArticleContent::Status::DRAFT).pluck(:id)
      sections = Section.where(program_id: organization.id)
      profile_questions = ProfileQuestion.where(organization_id: organization.id)
      profile_answers = ProfileAnswer.where(profile_question_id: profile_questions.pluck(:id))
      question_choices = QuestionChoice.where(ref_obj_id: profile_questions.pluck(:id), ref_obj_type: ProfileQuestion.name)
      three_sixty_organization_surveys = ThreeSixty::Survey.where(organization_id: organization.id)
      three_sixty_questions = ThreeSixty::Question.where(organization_id: organization.id)
      three_sixty_competencies = ThreeSixty::Competency.where(organization_id: organization.id)
      three_sixty_reviewer_groups = ThreeSixty::ReviewerGroup.where(organization_id: organization.id)
      abstract_messages = AbstractMessage.where(program_id: program_organization_ids)

      change_urls_for_objects_with_translations(AbstractProgram, [:zero_match_score_message, :allow_mentoring_requests_message, :description], abstract_programs)
      change_urls_for_objects_with_translations(Organization, [:agreement, :privacy_policy, :browser_warning, :favicon_link], [organization])
      change_urls_for_objects_with_translations(AuthConfig, [:password_message], auth_configs)
      change_urls_for_objects_with_translations(AuthConfigSetting, [:default_section_description, :custom_section_description], [organization.auth_config_setting].compact)
      change_urls_for_objects_with_translations(Page, [:content], pages)
      change_urls_for_objects_with_translations(Resource, [:content], resources)
      change_urls_for_objects_with_translations(Mailer::Template, [:source], mailer_templates)
      change_urls_for_objects_with_translations(Mailer::Widget, [:source], mailer_widgets)
      change_urls_for_objects_with_translations(Section, [:description], sections)
      change_urls_for_objects_with_translations(ProfileQuestion, [:question_text, :help_text], profile_questions)
      change_urls_for_objects_with_translations(QuestionChoice, [:text], question_choices)
      change_urls_for_objects_with_translations(ProfileAnswer, [:answer_text], profile_answers)
      change_urls_for_objects_with_translations(AbstractMessage, [:content], abstract_messages)
      change_urls_for_objects_with_translations(ThreeSixty::Survey, [:description, :title], three_sixty_organization_surveys)
      change_urls_for_objects_with_translations(ThreeSixty::Question, [:title], three_sixty_questions)
      change_urls_for_objects_with_translations(ThreeSixty::Competency, [:title, :description], three_sixty_competencies)
      change_urls_for_objects_with_translations(ThreeSixty::ReviewerGroup, [:name], three_sixty_reviewer_groups)

      # Program dependent models
      organization.programs.each do |program|
        published_article_ids = article_publications.where(program_id: program.id).pluck(:article_id)
        published_article_content_ids = articles.where(id: published_article_ids).pluck(:article_content_id)
        article_contents.where(id: published_article_content_ids + drafted_article_content_ids).each do |article_content|
          article_id = articles.where(article_content_id: article_content.id)[0].try(:id)
          if article_id
            change_urls(:body, article_content)
            change_urls(:embed_code, article_content, embed_media: true)
          end
          drafted_article_content_ids -= [article_content.id]
        end

        @es_reindex_hash["Article"] = articles.published.pluck(:id) unless @skip_es_reindex

        contact_admin_settings = ContactAdminSetting.where(program_id: program.id)
        cm_abstract_campaigns = CampaignManagement::AbstractCampaign.where(program_id: program.id)
        topics = Topic.where(forum_id: program.forum_ids)
        posts = Post.where(topic_id: topics.pluck(:id))
        announcements = Announcement.where(program_id: program.id)
        qa_questions = QaQuestion.where(program_id: program.id)
        qa_answers = QaAnswer.where(qa_question_id: qa_questions.select(:id))
        roles = Role.where(program_id: program.id)
        pages = Page.where(program_id: program.id)
        resources = Resource.where(program_id: program.id)
        mentoring_models = MentoringModel.where(program_id: program.id)
        mailer_templates = Mailer::Template.where(program_id: program.id)
        mailer_widgets = Mailer::Widget.where(program_id: program.id)
        program_events = ProgramEvent.where(program_id: program.id)
        program_invitations = ProgramInvitation.where(program_id: program.id)
        common_questions = CommonQuestion.where(program_id: program.id)
        common_answers = CommonAnswer.where(common_question_id: common_questions.pluck(:id))
        question_choices = QuestionChoice.where(ref_obj_id: common_questions.pluck(:id), ref_obj_type: CommonQuestion.name)
        group_closures = GroupClosureReason.where(program_id: program.id)
        instructions = AbstractInstruction.where(program_id: program.id)
        group_ids = Group.where(program_id: program.id).pluck(:id)

        change_urls_for_objects_with_translations(ContactAdminSetting, [:content], contact_admin_settings)
        change_urls_for_objects_with_translations(CampaignManagement::AbstractCampaign, [:title], cm_abstract_campaigns)
        change_urls_for_objects_with_translations(Topic, [:body], topics)
        change_urls_for_objects_with_translations(Post, [:body], posts)
        change_urls_for_objects_with_translations(Announcement, [:body], announcements)
        change_urls_for_objects_with_translations(QaQuestion, [:summary], qa_questions)
        change_urls_for_objects_with_translations(QaAnswer, [:content], qa_answers)
        change_urls_for_models_associated_with_groups(group_ids)
        change_urls_for_objects_with_translations(MentoringModel, [:description, :forum_help_text], mentoring_models)
        mentoring_models.each { |mentoring_model| change_urls_for_models_associated_with_mentoring_model(mentoring_model) }
        change_urls_for_objects_with_translations(Page, [:content], pages)
        change_urls_for_objects_with_translations(Resource, [:content], resources)
        change_urls_for_objects_with_translations(Role, [:description, :eligibility_message], roles)
        change_urls_for_objects_with_translations(Mailer::Template, [:source], mailer_templates)
        change_urls_for_objects_with_translations(Mailer::Widget, [:source], mailer_widgets)
        change_urls_for_objects_with_translations(ProgramEvent, [:description], program_events)
        change_urls_for_objects_with_translations(ProgramInvitation, [:message], program_invitations)
        change_urls_for_objects_with_translations(CommonQuestion, [:question_text, :help_text], common_questions)
        change_urls_for_objects_with_translations(QuestionChoice, [:text], question_choices)
        change_urls_for_objects_with_translations(CommonAnswer, [:answer_text], common_answers)
        change_urls_for_objects_with_translations(GroupClosureReason, [:reason], group_closures)
        change_urls_for_objects_with_translations(AbstractInstruction, [:content], instructions)
      end
    end
    reindex_es_models
    @info.close
    if @change_old_ids
      @change_old_ids_csv.close
      messages = ["Please take a look at the file #{@change_old_ids_csv_file_path} for urls in which old ids are not replaced."]
      messages << "Please check whether the mapping for the model name and route path needs to be added in @route_model_map in url_updater rake."
      messages << "Also update the 'Updated on' timestamp in url_updater.rb#1."
      Common::RakeModule::Utils.print_alert_messages(messages)
    end
  end
end