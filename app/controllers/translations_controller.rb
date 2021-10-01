class TranslationsController < ApplicationController
  include TranslatedCounts
  include TranslatedElements
  include TranslationsImport
  include CampaignManagement::CampaignsHelper

  skip_before_action :require_program, :login_required_in_program 
  before_action :login_required_in_organization
  allow :exec => :check_has_permission
  before_action :fetch_enabled_languages
  allow :exec => :language_presence
  before_action :require_super_user, only: [:export_csv, :import_csv]
  before_action :has_languages
  before_action :get_examined_object, only: [:index]
  before_action :get_second_locale
  before_action :get_level_object
  before_action :get_import_errors, only: [:index]
  before_action :get_scores_for_programs, only: [:index]
  before_action :get_category_and_base_id, except: [:export_csv, :import_csv]
  before_action :content_of_category, only: [:index, :show_category_content, :update_images]
  before_action :get_all_applicable_programs, only: [:index, :update_images]
  No_OF_PROGRAMS = 5

  def index
    @skip_rounded_white_box_for_content = true
    @rich_content_save = params[:rich_content_save]
  end

  def export_csv
    csv_file_name = ("feature.translations.label.csv_export_name".translate(date: DateTime.localize(Time.current, format: :csv_timestamp))).to_html_id
    csv_headers, export_attributes = generate_translations_csv(@current_organization, @level_obj, @second_locale)
    csv_data = CSV.generate do |csv|
      csv << csv_headers
      export_attributes.uniq.each do |attribute|
        csv << attribute
      end
    end
    send_csv csv_data, :disposition => "attachment; filename=#{csv_file_name}.csv"
  end

  def import_csv
    if !not_a_valid_file?(params[:user_csv])
      translation_import, valid_encoding = TranslationImport.save_csv_file(@level_obj, params[:user_csv])
      if !valid_encoding
        flash[:error] = "csv_import.content.encoding_error".translate
        redirect_to translations_path
        return
      else
        errors, second_locale = read_and_save_translations_csv(@current_organization, @level_obj, translation_import.local_csv_file_path)
        translation_import.info = errors
        translation_import.save!
        if errors[:lang_error]
          flash[:error] = "feature.translations.errors.import_second_locale".translate
          redirect_to translations_path
          return
        else
          if errors == {}
            flash[:notice] = "feature.translations.notice.import_success".translate
            redirect_to translations_path(locale: second_locale)
            return
          else
            link_content = "feature.translations.errors.error_link".translate
            flash[:warning] = "feature.translations.errors.import_errors".translate(:errors => "<a href='javascript:void(0)', data-toggle= 'modal', data-target='#cjs_translations_import_errors'>#{link_content}</a>".html_safe)
            redirect_to translations_path(import_id: translation_import.id, locale: second_locale)
            return
          end
        end
      end
    else
      redirect_to translations_path
      return
    end 
  end

  def show_category_content
  end

  def expand_category
    @category_detail = elements_of_category(@category, @level_obj)[:sub_heading]
  end

  def update
    obj_details = JSON.parse(params[:object])
    base_element = find_object_to_update(obj_details)
    attributes_by_model = LocalizableContent::attributes_for_model(category: @category, tab: @base_id)
    attributes_by_model[Organization] = attributes_by_model[AbstractProgram] + attributes_by_model[Organization] if @category == LocalizableContent::PROGRAM_SETTINGS && @base_id == ProgramsController::SettingsTabs::GENERAL
    if attributes_by_model[base_element.class].map(&:to_s).include?(obj_details["attribute"])
      attribute = obj_details["attribute"].to_sym
      type = LocalizableContent::ckeditor_type[base_element.class]
      if !type.present? || !type.keys.include?(attribute)
        response = {}
        GlobalizationUtils.run_in_locale(@second_locale) do
          params[:value] = nil if params[:value].blank?
          base_element[obj_details["attribute"]] = params[:value]
          modify_dependent_attributes(base_element, obj_details["attribute"], params[:value])
          set_block_mail(base_element)
          response = base_element.save ? {success: true} : {:success => false, message: base_element.errors.full_messages.to_sentence, val_in_locale: attr_in_locale(base_element.reload, obj_details["attribute"], @second_locale)}
        end
        clear_caches(base_element) if response[:success]
        @category_with_items = {}
        @category_with_items[@category] = elements_of_category(@category, @level_obj)
        render :json => response.merge(category_with_items: @category_with_items).to_json
      end
    else
      raise "feature.translations.errors.wrong_attribute".translate
    end
  end

  def update_images
    scan_and_save_attachment(params)
    @update_current_attachment = ((current_program_or_organization == @level_obj) && (current_locale.to_s == @second_locale.to_s))
    category_with_items = {}
    category_with_items[@category] = elements_of_category(@category, @level_obj)
    @category_with_items_json = category_with_items.to_json
  end

  def edit_content
    @skip_rounded_white_box_for_content = true
    obj_details = JSON.parse(params[:object])
    base_element = find_object_to_update(obj_details)
    heading_attr = LocalizableContent.attributes_for_model(category: @category, tab: @base_id)[base_element.class].first
    heading_attr = obj_details["attribute"] if base_element.is_a?(Organization)
    if LocalizableContent::ckeditor_type[base_element.class].keys.map(&:to_s).include?(obj_details["attribute"])
      attribute = obj_details["attribute"].to_sym
      @object_details = attribute_details(base_element, obj_details["attribute"], @second_locale, obj_details["higher_hierarchy"]).merge(heading: get_content_for_heading(@category, base_element, heading_attr)).merge(get_ckeditor_type(base_element, attribute))
    else
      raise "feature.translations.errors.wrong_attribute".translate
    end
  end

  def update_content
    obj_details = JSON.parse(params[:object])
    base_element = find_object_to_update(obj_details)
    if LocalizableContent::ckeditor_type[base_element.class].keys.map(&:to_s).include?(obj_details["attribute"])
      is_success = false
      GlobalizationUtils.run_in_locale(@second_locale) do
        params[:object_content] = nil if params[:object_content].blank?
        base_element[obj_details["attribute"]] = params[:object_content]
        assign_user_and_sanitization_version(base_element)
        set_block_mail(base_element)
        is_success = base_element.save
      end
      if is_success
        flash[:notice] = "flash_message.program_flash.updated".translate
        redirect_to translations_path(locale: @second_locale, category: @category, id: @base_id, abstract_program_id: @level_obj.id, examined_object: [base_element.class, base_element.id, obj_details["attribute"]], rich_content_save: true)
      else
        flash[:error] = base_element.errors.full_messages.to_sentence
        redirect_to edit_content_translations_path(locale: @second_locale, category: @category, id: @base_id, abstract_program_id: @level_obj.id, object: params[:object])
      end
    else
      raise "feature.translations.errors.wrong_attribute".translate
    end
  end

  private

  def set_block_mail(base_element)
    if base_element.instance_of?(ProgramEvent) || base_element.instance_of?(Announcement)
      base_element.block_mail = true
    end
  end

  def get_all_applicable_programs
    @progs = [@current_organization] + ProgramsListingService.get_applicable_programs(@current_organization)
  end

  def scan_and_save_attachment(params)
    attachment_type = params["id"]
    attachment_file = params[attachment_type]
    size_map = {"logo" => ProgramAsset::MAX_SIZE[ProgramAsset::Type::LOGO], "banner" => ProgramAsset::MAX_SIZE[ProgramAsset::Type::BANNER]}
    @errors = []
    if attachment_file && attachment_file.respond_to?(:read) && attachment_file.respond_to?(:original_filename) && PICTURE_CONTENT_TYPES.include?(attachment_file.content_type) && attachment_file.size < size_map[attachment_type]
      attachment_dir = attachment_file_dir(attachment_type)
      FileUtils.mkdir_p(attachment_dir, mode: 0777)
      file_path = File.join(attachment_dir, attachment_file.original_filename)
      File.open(file_path, 'wb') { |file| file.write(attachment_file.read) }

      unless ClamScanner.scan_file(file_path)
        FileUtils.rm_rf(file_path)
        @errors << 'flash_message.program_asset.errors.file_infected'.translate
      else
        save_attachment(attachment_type, params[attachment_type], @level_obj)
      end
    else
      if attachment_file.respond_to?(:content_type)
        @errors << 'flash_message.program_asset.file_attachment_invalid'.translate(attachment_type: attachment_type.capitalize, supported_file_types: PICTURE_CONTENT_TYPES.join(" ")) if !PICTURE_CONTENT_TYPES.include?(attachment_file.content_type)
        @errors << 'flash_message.program_asset.file_attachment_too_big'.translate(attachment_type: attachment_type.capitalize,file_size: size_map[attachment_type]/ONE_MEGABYTE) if attachment_file.size > size_map[attachment_type]
      else
        @errors << 'flash_message.program_asset.errors.invalid_stream'.translate
      end
    end
  end

  def save_attachment(attachment_type, attachment, prog_or_org)
    GlobalizationUtils.run_in_locale(@second_locale) do
      attachment_type == "logo" ? @program_asset.logo = attachment : @program_asset.banner = attachment
      @program_asset.save!
    end
    clear_caches(prog_or_org)
  end

  def attachment_file_dir(attachment_type)
    File.join(Rails.root, "tmp/", attachment_type, Time.now.to_i.to_s)
  end

  def require_super_user
    redirect_to translations_path if !super_console?
  end

  def get_examined_object
    if params[:examined_object].present?
      klass = params[:examined_object].first.constantize_only(LocalizableContent::attributes_for_model(category: @category, tab: @base_id).keys.map(&:name))
      @examined_object = {klass: klass, id: params[:examined_object].second.to_i}
      @examined_object.merge!(attribute: params[:examined_object].third.to_sym) if params[:examined_object].third.present?
    end
  end

  def get_ckeditor_type(ele, attribute)
    # campaign has only one attribute of mailer template i.e. source so not checking that
    special_campaign_case = @category == LocalizableContent::CAMPAIGN && ele.class == Mailer::Template
    special_facilitaion_case = @category == LocalizableContent::MENTORING_MODEL && ele.class == MentoringModel::FacilitationTemplate
    data_hash = {ckeditor_type: special_campaign_case ? :dropdown : LocalizableContent.ckeditor_type[ele.class][attribute]}
    if special_campaign_case
      campaign = ele.campaign_message.campaign
      data_hash[:label] = 'feature.campaigns.label.Insert_variable'.translate
      data_hash[:strinsert] = fetch_placeholders(campaign.campaign_email_tags, campaign.program)
    elsif special_facilitaion_case
      all_tags = ChronusActionMailer::Base.mailer_attributes[:tags][:facilitation_message_tags]
      data_hash[:label] = 'feature.facilitate_users.label.Insert_variables'.translate
      data_hash[:strinsert] = fetch_placeholders(all_tags, ele.mentoring_model.program)
    end
    return data_hash
  end

  def language_presence
    @enabled_languages.present? || wob_member.admin?
  end

  def fetch_enabled_languages
    @enabled_languages = Language.where(id: Language.supported_for(super_console?, wob_member, program_context).collect(&:id))
  end

  def has_languages
    if !@enabled_languages.present? && wob_member.admin?
      flash[:notice] = "feature.translations.label.language_absent".translate
      redirect_to organization_languages_path
    end
  end

  def check_has_permission
    program_view? ? current_user.can_manage_translations? : wob_member.admin?
  end

  def find_object_to_update_program_settings(obj_details)
    obj_hierarchy = obj_details["higher_hierarchy"]
    all_elements = @standalone_case ? [@level_obj, @level_obj.programs.first] : [@level_obj]
    base_element = []
    relation, lower_tree = LocalizableContent.tab_relations[@base_id]
    relation = [relation].flatten
    obj_hierarchy.each do |klass, id|
      base_element = [all_elements.find{|ele| (ele.id == id.to_i) && (ele.class == klass.constantize)}]
      if relation.compact.present?
        all_elements = relation.collect{|rel| base_element.collect{|level_obj| level_obj.send(rel)}}.flatten 
        relation, lower_tree = [[lower_tree]].first
        relation = [relation].flatten
      end
    end
    base_element.first
  end

  def find_object_to_update(obj_details)
    return find_object_to_update_program_settings(obj_details) if @category == LocalizableContent::PROGRAM_SETTINGS
    obj_hierarchy = obj_details["higher_hierarchy"]
    base_element = []
    if @standalone_case
      base_element << @level_obj if org_category?(@category)
      base_element << @level_obj.programs.first if prog_category?(@category)
    else
      base_element << @level_obj
    end
    relation, lower_tree = LocalizableContent.relations[@category].first
    relation = [relation]
    obj_hierarchy.each do |klass, id|
      all_elements = relation.collect{|rel| base_element.collect{|level_obj| level_obj.send(rel)}}.flatten
      base_element = [all_elements.find{|ele| (ele.id == id.to_i) && (ele.class == klass.constantize)}]
      relation, lower_tree = lower_tree.is_a?(Hash) ? lower_tree.first : [[lower_tree]].first
      relation = [relation].flatten
    end
    return base_element.first
  end

  def get_second_locale
    @second_locale = (@enabled_languages.find_by(language_name: params[:locale]) || @enabled_languages.first).language_name.to_sym
  end

  def get_import_errors
    if params[:import_id].present?
      translation_import = @level_obj.translation_imports.where(id: params[:import_id]).first
      if translation_import.present?
        @import_errors = translation_import.info
      end
    end
  end
  
  def get_level_object
    obj = program_view? ? @current_program : (@current_organization.programs.find_by(id: params[:abstract_program_id]) || @current_organization)
    @level_obj = obj.standalone? ? (obj.is_a?(Organization) ? obj : obj.organization) : obj
    @standalone_case = @level_obj.standalone?
  end

  def elements_of_category(category, level_obj)
    relation, lower_tree = LocalizableContent.relations[category].first
    items = []
    if @standalone_case
      items += [fetch_relation_objects(level_obj, relation)] if org_category?(category) #level object will be org
      items += [fetch_relation_objects(level_obj.programs.first, relation)] if prog_category?(category) 
    else
      items += [fetch_relation_objects(level_obj, relation)]
    end
    items = items.compact.flatten
    items = items.select{|i| i.logo_file_name.present? || i.banner_file_name.present?} if LocalizableContent.is_program_asset?(category)
    return nil unless items.present?
    if (heading = LocalizableContent.expands_to[category]).present?
      child_eles = items.uniq.collect{|ele| {id: ele[:id], heading: get_content_for_heading(category, ele, heading), score: get_dependent_objects_translated_count(category, ele, lower_tree, level_obj)}}
      child_eles = child_eles.select { |hsh| hsh[:score] != nil && hsh[:score] != [0,0] }
      return nil if child_eles.empty?
      return {sub_heading: child_eles, score: child_eles.map{|ele| ele[:score]}.transpose.map{|a| a.sum}}
    else
      value = LocalizableContent.is_program_asset?(category) ? get_content_for_logo_banners(category, items.first) : []
      score = value.present? ? value.map{|ele| ele[:score]}.transpose.map{|a| a.sum} : items.uniq.collect{|ele| get_dependent_objects_translated_count(category, ele, lower_tree, level_obj)}.transpose.map{|a| a.sum}
      return {sub_heading: value, score: score}
    end
  end

  def get_dependent_objects_translated_count_program_settings(item, level_obj)
    program_settings_tab_num = item[:id]
    objects = get_translatable_objects_program_settings(item[:id], level_obj)
    translated_count = objects.collect{|o| get_translation_score_or_elements_for_object(o, @second_locale, @standalone_case, LocalizableContent::PROGRAM_SETTINGS, program_settings_tab_num)}
    return (translated_count.empty? ? nil : translated_count.transpose.map{|a| a.sum})
  end

  def get_dependent_objects_translated_count(category, item, lower_tree, level_obj)
    return get_dependent_objects_translated_count_program_settings(item, level_obj) if category == LocalizableContent::PROGRAM_SETTINGS
    overall = [0,0]
    if lower_tree
      lower_tree.each do |tree|
        relation, next_tree = tree.is_a?(Hash) ? tree.first : tree
        fetch_relation_objects(item, relation).each do |object|
          obj_child_count = get_dependent_objects_translated_count(category, object, next_tree, level_obj)
          overall = [overall, obj_child_count].transpose.map{|a| a.sum} 
        end
      end
    end
    item_count_detail = get_translation_score_or_elements_for_object(item, @second_locale, @standalone_case, category)
    overall = [overall, item_count_detail].transpose.map{|a| a.sum} 
    return overall
  end

  def fetch_relation_objects(obj, relation)
    load = LocalizableContent.eager_load_association[relation]
    load.present? ? obj.send(relation).includes(load) : obj.send(relation)
  end

  def get_category_and_base_id
    if params[:category].present?
      @category = params[:category]
      @base_id = LocalizableContent.is_program_asset?(@category) ?  params[:id] : params[:id].to_i
      @attachment_type = params[:id] if ["logo", "banner"].include?(params[:id])
      @category_with_items = elements_of_category(@category, @level_obj)[:sub_heading] if LocalizableContent.expands_to.keys.include?(@category) || LocalizableContent.is_program_asset?(@category)
    else
      @category = @category_with_scores.keys.first
      if LocalizableContent.expands_to.keys.include?(@category)
        @category_with_items = elements_of_category(@category, @level_obj)[:sub_heading]
        @base_id = @category_with_items.first[:id]
      end
    end
  end

  def get_scores_for_programs
    cur_obj = program_view? ? @level_obj : @current_organization
    scores_by_program_category = get_score_for_prog_or_org(cur_obj, @second_locale)
    @programs_score = {}
    scores_by_program_category.each do |program_id, score_by_category|
      @programs_score[program_id] = score_by_category.values.transpose.map{|a| a.sum}
      @programs_score[program_id] = [0, 0] if @programs_score[program_id].empty?
    end
    @category_with_scores = scores_by_program_category[@level_obj.id]
  end

  def get_content_for_programs_settings
    get_translatable_objects_program_settings(@base_id, @level_obj).each do |object|
      attr_of_object = []
      attributes_by_model = LocalizableContent::attributes_for_model(category: LocalizableContent::PROGRAM_SETTINGS, tab: @base_id)
      attributes = attributes_by_model[object.class]
      scope = case @base_id
        when ProgramsController::SettingsTabs::GENERAL, ProgramsController::SettingsTabs::MATCHING
          []
        when ProgramsController::SettingsTabs::TERMINOLOGY
          high_obj = (object.term_type == CustomizedTerm::TermType::ROLE_TERM) ? object.ref_obj.program : object.ref_obj
          [[high_obj.class.to_s, high_obj.id]]
        when ProgramsController::SettingsTabs::MEMBERSHIP, ProgramsController::SettingsTabs::CONNECTION
          obj = (@standalone_case ? @level_obj.programs.first : @level_obj)
          [[obj.class.to_s, obj.id]]
        end + [[object.class.to_s, object.id]]
      attributes = attributes_by_model[AbstractProgram] if object.is_a?(Organization) && @category == LocalizableContent::PROGRAM_SETTINGS && @base_id == ProgramsController::SettingsTabs::GENERAL
      attributes.each do |attribute|
        attr_of_object << attribute_details(object, attribute, @second_locale, scope)
      end
      @translatable_content << attr_of_object
      if @category == LocalizableContent::PROGRAM_SETTINGS && @base_id == ProgramsController::SettingsTabs::GENERAL && (@standalone_case || object.is_a?(Organization))
        attributes_by_model[Organization].each do |attribute|
          next unless (@level_obj.translations.select{|t| t.locale == :en}.first || {})[attribute].present?
          @translatable_content << [attribute_details(@level_obj, attribute, @second_locale, [[@level_obj.class.to_s, @level_obj.id]], :heading => "program_settings_strings.header.#{LocalizableContent::organization_attributes_translations[attribute]}".translate)]
        end
      end
    end
  end

  def get_content_for_logo_banners(category, item)
    attachments = get_attachments_for_program_asset(item)
    attachments.inject([]) do |my_hash, attachment|
      my_hash << {:id => "#{attachment}", :heading => "feature.translations.categories.#{attachment}".translate, :score => get_translation_score_or_elements_for_object(item, @second_locale, @standalone_case, category, nil, attachment)}
    end
  end

  def get_attachments_for_program_asset(program_asset)
    attribute_map = {:logo_file_name => "logo", :banner_file_name => "banner"}
    attribute_map.inject([]) do |attachments, (attribute, attachment)|
      attachments << attachment if program_asset.send(attribute).present?
      attachments
    end
  end

  def content_of_category
    @translatable_content = []
    if @category == LocalizableContent::PROGRAM_SETTINGS
      get_content_for_programs_settings
    else
      hierarchy = LocalizableContent.relations[@category]
      higher_hierarchy = []
      dependency = hierarchy
      base_element = @standalone_case ? (LocalizableContent.org_level.include?(@category) ? @level_obj : @level_obj.programs.first) : @level_obj
      # will have to check case where category belongs to organization but does not expand, do not have any such case so works fine
      if LocalizableContent.expands_to.keys.include?(@category)
        relation, dependency = hierarchy.first
        if @standalone_case
          base_element = @level_obj.send(relation).find_by(id: @base_id) if org_category?(@category)
          base_element = @level_obj.programs.first.send(relation).find_by(id: @base_id) if !org_category?(@category) || (prog_category?(@category) && base_element.nil?)
        else
          base_element = @level_obj.send(relation).find_by(id: @base_id)
        end
        higher_hierarchy << [base_element.class.to_s, @base_id]
        if can_item_be_edited?(base_element)
          attr_of_object = []
          attributes = LocalizableContent::attributes_for_model(category: @category, tab: @base_id)[base_element.class]
          attributes.each do |attribute|
            attr_of_object << attribute_details(base_element, attribute, @second_locale, higher_hierarchy.dup())
          end
          @translatable_content << attr_of_object
        end
      end
      get_lower_level_elements(dependency, base_element, higher_hierarchy.dup()) if dependency.present?
    end
  end

  def get_lower_level_elements(hierarchy, object, higher_hierarchy)
    hierarchy.each do |list|
      relation, lower_tree = list.is_a?(Hash) ? list.first : list
      elements = [fetch_relation_objects(object, relation)].flatten
      @program_asset = elements.first if LocalizableContent.is_program_asset?(@category)
      klass = elements.first.class
      attributes = LocalizableContent::attributes_for_model(category: @category, tab: @base_id)[klass]
      elements.each do |ele|
        dup_higher_hierarchy = (higher_hierarchy.dup() << [ele.class.to_s, ele.id])
        if can_item_be_edited?(ele)
          attr_of_object = []
          attributes.each do |attribute|
            attr_of_object << attribute_details(ele, attribute, @second_locale, dup_higher_hierarchy)
          end
          @translatable_content << attr_of_object
        end
        get_lower_level_elements(lower_tree, ele, dup_higher_hierarchy) if lower_tree.present?
      end
    end
  end

  def attribute_details(obj, attribute, locale, higher_hierarchy, options = {})
    if LocalizableContent.attribute_for_heading[obj.class] && LocalizableContent.attribute_for_heading[obj.class].include?(attribute)
      # this is just for heading no translation exists therefore can directly use obj.attribute because if it does we will be translating that also in tool
      obj_role_name = GlobalizationUtils.run_in_locale(I18n.default_locale) { obj.customized_term.term }
      return {klass: obj.class.to_s, id: obj.id, en: obj_role_name, for_heading: true}
    else
      return {category: @category,
          id: obj.id, 
          klass: obj.class.to_s,
          attribute: attribute,
          higher_hierarchy: higher_hierarchy,
          en: attr_in_locale(obj, attribute, :en),
          locale => attr_in_locale(obj, attribute, locale)
        }.merge(options)
    end
  end

  def attr_in_locale(obj, attribute, locale)
    obj.translation_for(locale, false).try(attribute)
  end

  def clear_caches(object)
    case
      when object.is_a?(Program) || object.is_a?(Organization)
        expire_banner_cached_fragments(object)
      when object.is_a?(Section) || object.is_a?(ProfileQuestion) || object.is_a?(QuestionChoice)
        expire_cached_program_user_filters
    end
  end

  def modify_dependent_attributes(base_element, attribute_name, attribute_value)
    return unless (LocalizableContent.dependent_attributes[base_element.class].present? && LocalizableContent.dependent_attributes[base_element.class][attribute_name.to_sym].present?)
    LocalizableContent.dependent_attributes[base_element.class][attribute_name.to_sym].each do |dependent_attribute_name, method|
      base_element[dependent_attribute_name] = base_element.send(method.to_sym, attribute_value)
    end
  end

  def get_content_for_heading(category, base_element, attribute)
    content = LocalizableContent.content_for_heading(category, base_element, attribute)
    return instructions_custom_title[content] if category == LocalizableContent::INSTRUCTION
    return content
  end

  def instructions_custom_title
  {
    MentorRequest::Instruction => "feature.translations.label.mentor_request_instruction".translate(:mentor => _Mentor),
    MembershipRequest::Instruction => "feature.translations.label.membership_instruction".translate
  }
  end

  def not_a_valid_file?(csv_stream)
    invalid_file = true
    if !csv_stream || !File.size?(csv_stream.path) || File.extname(csv_stream.original_filename) != ".csv"
      flash[:error] = "csv_import.content.upload_valid_csv".translate
    elsif !ClamScanner.scan_file(csv_stream.path)
      FileUtils.rm_rf(csv_stream.path)
      flash[:error] = "feature.translations.errors.infect_file".translate
    else
      invalid_file = false
    end
    return invalid_file
  end

end