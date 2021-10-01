require_relative './../../test_helper.rb'

class TranslatedElementsTest < ActionView::TestCase
  include TranslatedElements
  include TranslatedCounts

  def test_get_attributes_to_export_for_program
    program = programs(:albers)
    program_elements = get_attributes_to_export(program, "es")
    
    ids = program.announcements.pluck(:id)
    announcement_title_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    en_hash_title = Hash[announcement_title_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_title.keys()
    other_locale_ids_and_attr = Announcement::Translation.where("announcement_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_title, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash_title[k] || "", other_locale_hash[k] || ""]
    end

    announcement_body_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    en_hash_body = Hash[announcement_body_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_body.keys()
    other_locale_ids_and_attr = Announcement::Translation.where("announcement_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_body, other_locale_hash].flat_map(&:keys).uniq
    total_elements += keys.map do |k| 
      [ en_hash_body[k] || "", other_locale_hash[k] || ""]
    end

    assert_equal [], total_elements - program_elements

    TranslatedElementsTest.any_instance.expects(:get_prog_or_org_elements).with(program, "es").once
    get_attributes_to_export(program, "es")
  end

  def test_get_attributes_to_export_for_organization
    organization = programs(:org_primary)
    assert organization.is_a?(Organization)
    organization_elements = get_attributes_to_export(organization, "es")

    ids = organization.pages.pluck(:id)
    overview_pages_title_objects = Page::Translation.where("page_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:page_id, :title)
    en_hash_title = Hash[overview_pages_title_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_title.keys()
    other_locale_ids_and_attr = Page::Translation.where("page_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(title,'') <> ''").pluck(:page_id, :title)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_title, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash_title[k] || "", other_locale_hash[k] || ""]
    end

    overview_pages_content_objects = Page::Translation.where("page_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(content,'') <> ''").pluck(:page_id, :content)
    en_hash_content = Hash[overview_pages_content_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_content.keys()
    other_locale_ids_and_attr = Page::Translation.where("page_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(content,'') <> ''").pluck(:page_id, :content)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_content, other_locale_hash].flat_map(&:keys).uniq
    total_elements += keys.map do |k| 
      [ en_hash_content[k] || "", other_locale_hash[k] || ""]
    end

    assert_equal [], total_elements - organization_elements

    ids = organization.programs.first.announcements.pluck(:id)
    announcement_title_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    en_hash_title = Hash[announcement_title_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_title.keys()
    other_locale_ids_and_attr = Announcement::Translation.where("announcement_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_title, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash_title[k] || "", other_locale_hash[k] || ""]
    end

    announcement_body_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    en_hash_body = Hash[announcement_body_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_body.keys()
    other_locale_ids_and_attr = Announcement::Translation.where("announcement_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_body, other_locale_hash].flat_map(&:keys).uniq
    total_elements += keys.map do |k| 
      [ en_hash_body[k] || "", other_locale_hash[k] || ""]
    end

    assert_equal [], total_elements - organization_elements

    TranslatedElementsTest.any_instance.expects(:get_prog_or_org_elements).with(organization, "es").once
    organization.programs.each do |prog|
      TranslatedElementsTest.any_instance.expects(:get_prog_or_org_elements).with(prog, "es").once
    end
    get_attributes_to_export(organization, "es")
  end

  def test_get_attributes_to_export_for_standalone
    organization = programs(:org_foster)
    assert organization.standalone?
    organization_elements = get_prog_or_org_elements(organization, "es")
    ids = organization.pages.pluck(:id)
    overview_pages_title_objects = Page::Translation.where("page_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:page_id, :title)
    en_hash_title = Hash[overview_pages_title_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_title.keys()
    other_locale_ids_and_attr = Page::Translation.where("page_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(title,'') <> ''").pluck(:page_id, :title)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_title, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash_title[k] || "", other_locale_hash[k] || ""]
    end

    overview_pages_content_objects = Page::Translation.where("page_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(content,'') <> ''").pluck(:page_id, :content)
    en_hash_content = Hash[overview_pages_content_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_content.keys()
    other_locale_ids_and_attr = Page::Translation.where("page_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(content,'') <> ''").pluck(:page_id, :content)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_content, other_locale_hash].flat_map(&:keys).uniq
    total_elements += keys.map do |k| 
      [ en_hash_content[k] || "", other_locale_hash[k] || ""]
    end

    assert_equal [], total_elements - organization_elements

    TranslatedElementsTest.any_instance.expects(:get_prog_or_org_elements).with(organization, "es").once
    TranslatedElementsTest.any_instance.expects(:get_prog_or_org_elements).with(organization.programs.first, "es").once
    get_attributes_to_export(organization, "es")
  end

  def test_get_prog_or_org_elements_at_prog_level
    program = programs(:albers)
    program_elements = get_prog_or_org_elements(program, "es")

    ids = program.announcements.pluck(:id)
    announcement_title_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    en_hash_title = Hash[announcement_title_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_title.keys()
    other_locale_ids_and_attr = Announcement::Translation.where("announcement_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_title, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash_title[k] || "", other_locale_hash[k] || ""]
    end

    announcement_body_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    en_hash_body = Hash[announcement_body_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_body.keys()
    other_locale_ids_and_attr = Announcement::Translation.where("announcement_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_body, other_locale_hash].flat_map(&:keys).uniq
    total_elements += keys.map do |k| 
      [ en_hash_body[k] || "", other_locale_hash[k] || ""]
    end

    assert_equal [], total_elements - program_elements

    LocalizableContent.program_level.each do |category|
      if can_show_category?(category, program)
        TranslatedElementsTest.any_instance.expects(:get_category_elements).with(category, program, "es").once
      end
    end
    get_prog_or_org_elements(program, "es")
  end

  def test_get_prog_or_org_elements_at_org_level
    organization = programs(:org_primary)
    organization_elements = get_prog_or_org_elements(organization, "es")
    ids = organization.pages.pluck(:id)
    overview_pages_title_objects = Page::Translation.where("page_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:page_id, :title)
    en_hash_title = Hash[overview_pages_title_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_title.keys()
    other_locale_ids_and_attr = Page::Translation.where("page_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(title,'') <> ''").pluck(:page_id, :title)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_title, other_locale_hash].flat_map(&:keys).uniq
    total_elements = keys.map do |k| 
      [ en_hash_title[k] || "", other_locale_hash[k] || ""]
    end

    overview_pages_content_objects = Page::Translation.where("page_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(content,'') <> ''").pluck(:page_id, :content)
    en_hash_content = Hash[overview_pages_content_objects.map {|key, value| [key, value]}]
    en_translated_ids = en_hash_content.keys()
    other_locale_ids_and_attr = Page::Translation.where("page_id IN (#{en_translated_ids.join(',')}) AND locale = 'es' AND ifnull(content,'') <> ''").pluck(:page_id, :content)
    other_locale_hash = Hash[other_locale_ids_and_attr.map {|key, value| [key, value]}]
    keys = [en_hash_content, other_locale_hash].flat_map(&:keys).uniq
    total_elements += keys.map do |k| 
      [ en_hash_content[k] || "", other_locale_hash[k] || ""]
    end

    assert_equal [], total_elements - organization_elements

    LocalizableContent.org_level.each do |category|
      if can_show_category?(category, organization)
        TranslatedElementsTest.any_instance.expects(:get_category_elements).with(category, organization, "es").once
      end
    end
    get_prog_or_org_elements(organization, "es")
  end

  def test_can_show_category_at_prog_level
    program = programs(:albers)
    program.enable_feature(FeatureName::RESOURCES)
    assert_equal true, can_show_category?(RESOURCES, program)
    
    program.enable_disable_feature(FeatureName::RESOURCES, false)
    assert_equal false, can_show_category?(RESOURCES, program)
  end

  def test_can_show_category_at_org_level
    organization = programs(:org_primary)
    organization.enable_feature(FeatureName::RESOURCES)
    assert_equal true, can_show_category?(RESOURCES, organization)
    
    organization.enable_disable_feature(FeatureName::RESOURCES, false)
    assert_equal false, can_show_category?(RESOURCES, organization)
  end

  def test_get_category_elements
    program = programs(:albers)
    category_elements = get_category_elements(LocalizableContent::ANNOUNCEMENT, program, "es")

    ids = program.announcements.pluck(:id)
    title_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    body_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    assert_equal title_objects.count+body_objects.count, category_elements.first.count+category_elements.second.count
    
    en_title = category_elements.first.first.first
    en_body = category_elements.second.first.first
    program.announcements.first.translations.create!(title: "Hello", body: "Hai", locale: "es")
    category_elements = get_category_elements(LocalizableContent::ANNOUNCEMENT, program, "es")
    assert_equal [en_title, "Hello"], category_elements.first.first
    assert_equal [en_body, "Hai"], category_elements.second[0]

    TranslatedElementsTest.any_instance.expects(:get_category_tree_elements).once
    get_category_elements(LocalizableContent::ANNOUNCEMENT, program, "es")
  end

  def test_get_category_elements_for_program_settings
    program = programs(:albers)
    category_elements = get_category_elements(LocalizableContent::PROGRAM_SETTINGS, program, "es")
    assert_equal [[["Albers Mentor Program", ""], ["Albers Mentor Program", ""], ["Mentor", ""], ["Mentors", ""], ["a Mentor", ""], ["Student", ""], ["Students", ""], ["a Student", ""], ["User", ""], ["Users", ""], ["an User", ""], ["Mentoring Connection", ""], ["Mentoring Connections", ""], ["a Mentoring Connection", ""], ["Article", ""], ["Articles", ""], ["an Article", ""], ["Meeting", ""], ["Meetings", ""], ["a Meeting", ""], ["Resource", ""], ["Resources", ""], ["a Resource", ""], ["Mentoring", ""], ["Mentorings", ""], ["a Mentoring", ""], ["Mentors are professionals who guide and advise mentees in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their mentees.", "[[ Mentors ářé ƿřóƒéššíóɳáłš ŵĥó ǧůíďé áɳď áďνíšé mentees íɳ ťĥéíř čářééř ƿáťĥš ťó ĥéłƿ ťĥéɱ šůččééď. Á mentor'š řółé íš ťó íɳšƿířé, éɳčóůřáǧé, áɳď šůƿƿóřť ťĥéíř mentees. ]]"], ["Mentees are students who want guidance and advice to further their careers and to be successful. Mentees can expect to strengthen and build their networks, and gain the skills and confidence necessary to excel.", "[[ Mentees ářé šťůďéɳťš ŵĥó ŵáɳť ǧůíďáɳčé áɳď áďνíčé ťó ƒůřťĥéř ťĥéíř čářééřš áɳď ťó ƀé šůččéššƒůł. Mentees čáɳ éхƿéčť ťó šťřéɳǧťĥéɳ áɳď ƀůíłď ťĥéíř ɳéťŵóřǩš, áɳď ǧáíɳ ťĥé šǩíłłš áɳď čóɳƒíďéɳčé ɳéčéššářý ťó éхčéł. ]]"], ["Not a match", "[[ Ѝóť á ɱáťčĥ ]]"]]], category_elements

    TranslatedElementsTest.any_instance.expects(:get_program_settings_elements).once
    get_category_elements(LocalizableContent::PROGRAM_SETTINGS, program, "es")
  end

  def test_get_category_tree_elements
    program = programs(:albers)
    
    tree = LocalizableContent.relations[LocalizableContent::RESOURCES]
    assert_equal [], get_category_tree_elements(tree, [], "es", Program)
    assert_equal [], get_category_tree_elements(tree, [program.id], "es", Program)

    tree = LocalizableContent.relations[LocalizableContent::ANNOUNCEMENT]
    ids = program.announcements.pluck(:id)
    title_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    body_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)
    assert_equal title_objects.count+body_objects.count, category_elements.first.count+category_elements.second.count
    
    en_title = category_elements.first.first.first
    en_body = category_elements.second.first.first
    program.announcements.first.translations.create!(title: "Hello", body: "Hai", locale: "es")
    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)
    assert_equal [en_title, "Hello"], category_elements.first.first
    assert_equal [en_body, "Hai"], category_elements.second[0]
  end

  def test_get_category_tree_elements_for_hash
    program = programs(:albers)
    tree = LocalizableContent.relations[LocalizableContent::CAMPAIGN]
    count = {}
    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)
    ids = program.abstract_campaigns.pluck(:id)
    count[:abstract_campaigns_title] = CampaignManagement::AbstractCampaign::Translation.where("cm_campaign_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:cm_campaign_id, :title)

    klass, foreign_key_column_name = klass_with_parent_foreign_key[:email_templates]
    ids = get_object_ids_for_node(klass, ids, foreign_key_column_name, CampaignManagement::AbstractCampaign)
    count[:abstract_campaigns_email_template_subject] = Mailer::Template::Translation.where("mailer_template_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(subject,'') <> ''").pluck(:mailer_template_id, :subject)
    count[:abstract_campaigns_email_template_source] = Mailer::Template::Translation.where("mailer_template_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(source,'') <> ''").pluck(:mailer_template_id, :source)

    assert_equal count[:abstract_campaigns_title].count, category_elements.first.count
    assert_equal count[:abstract_campaigns_email_template_subject].count, category_elements.second.count
    assert_equal count[:abstract_campaigns_email_template_source].count, category_elements.third.count

    program.abstract_campaigns.first.email_templates.first.translations.create!(locale: "es", source: "source", subject: "subject")
    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)

    assert_equal count[:abstract_campaigns_title].count, category_elements.first.count
    assert_equal count[:abstract_campaigns_email_template_subject].count, category_elements.second.count
    assert_equal count[:abstract_campaigns_email_template_source].count, category_elements.third.count

    assert_equal "subject", category_elements.second.first.second
    assert_equal "source", category_elements.third.first.second
  end

  def test_get_klass_elements
    program = programs(:albers)
    ids = program.announcements.pluck(:id)
    title_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(title,'') <> ''").pluck(:announcement_id, :title)
    body_objects = Announcement::Translation.where("announcement_id IN (#{ids.join(',')}) AND locale = 'en' AND ifnull(body,'') <> ''").pluck(:announcement_id, :body)
    klass_elements = get_klass_elements(Announcement, program.announcements.pluck(:id), "es")
    assert_equal title_objects.count+body_objects.count, klass_elements.first.count+klass_elements.second.count
    
    en_title = klass_elements.first.first.first
    en_body = klass_elements.second.first.first
    program.announcements.first.translations.create!(title: "Hello", body: "Hai", locale: "es")
    klass_elements = get_klass_elements(Announcement, program.announcements.pluck(:id), "es")
    assert_equal [en_title, "Hello"], klass_elements.first.first
    assert_equal [en_body, "Hai"], klass_elements.second[0]
  end

  def test_klass_elements_by_column
    program = programs(:albers)
    assert_equal [["All come to audi small", ""], ["All come to audi big announce", ""], ["expired announcement", ""], ["Drafted Announcement", ""]], get_klass_elements_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")
    program.announcements.first.translations.create!(title: "Hello", body: "Hai", locale: "es")
    assert_equal [["All come to audi small", "Hello"], ["All come to audi big announce", ""], ["expired announcement", ""], ["Drafted Announcement", ""]], get_klass_elements_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")
  end

  def test_get_program_settings_elements
    program = programs(:albers)
    tab_elements_in_program = {
      ProgramsController::SettingsTabs::GENERAL => [["Albers Mentor Program", ""], ["Albers Mentor Program", ""]],
      ProgramsController::SettingsTabs::TERMINOLOGY => [
        ["Mentor", ""], ["Mentors", ""], ["a Mentor", ""],
        ["Student", ""], ["Students", ""], ["a Student", ""],
        ["User", ""], ["Users", ""], ["an User", ""],
        ["Mentoring Connection", ""], ["Mentoring Connections", ""], ["a Mentoring Connection", ""],
        ["Article", ""], ["Articles", ""], ["an Article", ""],
        ["Meeting", ""], ["Meetings", ""], ["a Meeting", ""],
        ["Resource", ""],["Resources", ""], ["a Resource", ""],
        ["Mentoring", ""], ["Mentorings", ""], ["a Mentoring", ""]],
      ProgramsController::SettingsTabs::MEMBERSHIP => [["Mentors are professionals who guide and advise mentees in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their mentees.", "[[ Mentors ářé ƿřóƒéššíóɳáłš ŵĥó ǧůíďé áɳď áďνíšé mentees íɳ ťĥéíř čářééř ƿáťĥš ťó ĥéłƿ ťĥéɱ šůččééď. Á mentor'š řółé íš ťó íɳšƿířé, éɳčóůřáǧé, áɳď šůƿƿóřť ťĥéíř mentees. ]]"],
 ["Mentees are students who want guidance and advice to further their careers and to be successful. Mentees can expect to strengthen and build their networks, and gain the skills and confidence necessary to excel.", "[[ Mentees ářé šťůďéɳťš ŵĥó ŵáɳť ǧůíďáɳčé áɳď áďνíčé ťó ƒůřťĥéř ťĥéíř čářééřš áɳď ťó ƀé šůččéššƒůł. Mentees čáɳ éхƿéčť ťó šťřéɳǧťĥéɳ áɳď ƀůíłď ťĥéíř ɳéťŵóřǩš, áɳď ǧáíɳ ťĥé šǩíłłš áɳď čóɳƒíďéɳčé ɳéčéššářý ťó éхčéł. ]]"]],
      ProgramsController::SettingsTabs::MATCHING => [["Not a match", "[[ Ѝóť á ɱáťčĥ ]]"]]
    }
    program_settings_elements = get_program_settings_elements(program, "es").first
    elements_in_program = []
    tab_elements_in_program.each do |tab, elements|
      elements_in_program += tab_elements_in_program[tab]
    end
    assert_equal elements_in_program, program_settings_elements
  end

  def test_get_translation_score_or_elements_for_object
    program = programs(:albers)
    settings_sub_category = program.translation_settings_sub_categories.first
    item = get_translatable_objects_program_settings(settings_sub_category[:id], program).first
    translation_elements = get_translation_score_or_elements_for_object(item, "es", program.standalone?, LocalizableContent::PROGRAM_SETTINGS, tab = settings_sub_category[:id], attachment = nil, score = false)
    assert_equal [["Albers Mentor Program", ""], ["Albers Mentor Program", ""]], translation_elements
  end

end