require_relative './../../test_helper.rb'

class TranslationsImportTest < ActionView::TestCase
  include TranslationsImport
  include TranslatedCounts
  include TranslatedElements

  def test_set_translations_for_program
    program = programs(:albers)
    TranslationsImportTest.any_instance.expects(:set_prog_or_org_translations).with(program, [], "es").once
    set_translations(program, [], "es")
  end

  def test_set_translations_for_organization
    organization = programs(:org_primary)
    assert organization.is_a?(Organization)
    TranslationsImportTest.any_instance.expects(:set_prog_or_org_translations).with(organization, [], "es").once
    organization.programs.each do |prog|
      TranslationsImportTest.any_instance.expects(:set_prog_or_org_translations).with(prog, [], "es").once
    end
    set_translations(organization, [], "es")
  end

  def test_set_translations_for_standalone
    organization = programs(:org_foster)
    assert organization.standalone?
    TranslationsImportTest.any_instance.expects(:set_prog_or_org_translations).with(organization, [], "es").once
    TranslationsImportTest.any_instance.expects(:set_prog_or_org_translations).with(organization.programs.first, [], "es").once
    set_translations(organization, [], "es")
  end

  def test_set_prog_or_org_translations_at_prog_level
    program = programs(:albers)
    LocalizableContent.program_level.each do |category|
      if can_show_category?(category, program)
        TranslationsImportTest.any_instance.expects(:set_category_translations).with(category, program, [], "es").once
      end
    end
    set_prog_or_org_translations(program, [], "es")
  end

  def test_set_prog_or_org_translations_at_org_level
    organization = programs(:org_primary)
    LocalizableContent.org_level.each do |category|
      if can_show_category?(category, organization)
        TranslationsImportTest.any_instance.expects(:set_category_translations).with(category, organization, [], "es").once
      end
    end
    set_prog_or_org_translations(organization, [], "es")
  end

  def test_set_category_translations
    program = programs(:albers)
    data = {
      "All come to audi small" => "es - All come to audi small",
      "All people should assemble in Vivek audi" => "es - All people should assemble in Vivek audi"
    }
    category_elements = get_category_elements(LocalizableContent::ANNOUNCEMENT, program, "es")
    assert_equal ["All come to audi small",""], category_elements.first.first
    assert_equal ["All people should assemble in Vivek audi", ""], category_elements.second.first

    set_category_translations(LocalizableContent::ANNOUNCEMENT, program, data, "es")
    
    category_elements = get_category_elements(LocalizableContent::ANNOUNCEMENT, program, "es")
    assert_equal ["All come to audi small", "es - All come to audi small"], category_elements.first.first
    assert_equal ["All people should assemble in Vivek audi", "es - All people should assemble in Vivek audi"], category_elements.second.first

   	TranslationsImportTest.any_instance.expects(:set_category_tree_translations).once
   	set_category_translations(LocalizableContent::ANNOUNCEMENT, program, [], "es")

  end

  def test_set_category_translations_for_program_settings
	  program = programs(:albers)
    data = {
      "Article" => "es - Article",
      "Resource" => "es - Resource",
      "Mentees are students who want guidance and advice to further their careers and to be successful. Mentees can expect to strengthen and build their networks, and gain the skills and confidence necessary to excel." => "[[ es - Mentees ářé šťůďéɳťš ŵĥó ŵáɳť ǧůíďáɳčé áɳď áďνíčé ťó ƒůřťĥéř ťĥéíř čářééřš áɳď ťó ƀé šůččéššƒůł. Mentees čáɳ éхƿéčť ťó šťřéɳǧťĥéɳ áɳď ƀůíłď ťĥéíř ɳéťŵóřǩš, áɳď ǧáíɳ ťĥé šǩíłłš áɳď čóɳƒíďéɳčé ɳéčéššářý ťó éхčéł. ]]"
    }
    set_category_translations(LocalizableContent::PROGRAM_SETTINGS, program, data, "es")

    category_elements = get_category_elements(LocalizableContent::PROGRAM_SETTINGS, program, "es")
    assert_equal [[["Albers Mentor Program", ""], ["Albers Mentor Program", ""], ["Mentor", ""], ["Mentors", ""], ["a Mentor", ""], ["Student", ""], ["Students", ""], ["a Student", ""], ["User", ""], ["Users", ""], ["an User", ""], ["Mentoring Connection", ""], ["Mentoring Connections", ""], ["a Mentoring Connection", ""], ["Article", "es - Article"], ["Articles", ""], ["an Article", ""], ["Meeting", ""], ["Meetings", ""], ["a Meeting", ""], ["Resource", "es - Resource"], ["Resources", ""], ["a Resource", ""], ["Mentoring", ""], ["Mentorings", ""], ["a Mentoring", ""], ["Mentors are professionals who guide and advise mentees in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their mentees.", "[[ Mentors ářé ƿřóƒéššíóɳáłš ŵĥó ǧůíďé áɳď áďνíšé mentees íɳ ťĥéíř čářééř ƿáťĥš ťó ĥéłƿ ťĥéɱ šůččééď. Á mentor'š řółé íš ťó íɳšƿířé, éɳčóůřáǧé, áɳď šůƿƿóřť ťĥéíř mentees. ]]"], ["Mentees are students who want guidance and advice to further their careers and to be successful. Mentees can expect to strengthen and build their networks, and gain the skills and confidence necessary to excel.", "[[ es - Mentees ářé šťůďéɳťš ŵĥó ŵáɳť ǧůíďáɳčé áɳď áďνíčé ťó ƒůřťĥéř ťĥéíř čářééřš áɳď ťó ƀé šůččéššƒůł. Mentees čáɳ éхƿéčť ťó šťřéɳǧťĥéɳ áɳď ƀůíłď ťĥéíř ɳéťŵóřǩš, áɳď ǧáíɳ ťĥé šǩíłłš áɳď čóɳƒíďéɳčé ɳéčéššářý ťó éхčéł. ]]"], ["Not a match", "[[ Ѝóť á ɱáťčĥ ]]"]]], category_elements

	  TranslationsImportTest.any_instance.expects(:set_program_settings_translations).once
	  set_category_translations(LocalizableContent::PROGRAM_SETTINGS, program, [], "es")
  end

  def test_set_category_tree_translations_for_empty_objects
    program = programs(:albers)
    tree = LocalizableContent.relations[LocalizableContent::RESOURCES]
    set_category_tree_translations(tree, [], [], "es", Program)
    set_category_tree_translations(tree, [program.id], [], "es", Program) 
    TranslationsImportTest.any_instance.expects(:set_category_tree_translations).times(2)
    TranslationsImportTest.any_instance.expects(:set_klass_translations).times(0)
    set_category_tree_translations(tree, [], [], "es", Program)
    set_category_tree_translations(tree, [program.id], [], "es", Program)
  end

  def test_set_category_tree_translations
    program = programs(:albers)
    data = {
      "All come to audi small" => "es - All come to audi small",
      "All people should assemble in Vivek audi" => "es - All people should assemble in Vivek audi"
    }
    tree = LocalizableContent.relations[LocalizableContent::ANNOUNCEMENT]

    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)
    assert_equal ["All come to audi small",""], category_elements.first.first
    assert_equal ["All people should assemble in Vivek audi", ""], category_elements.second.first

    set_category_tree_translations(tree, [program.id], data, "es", Program)
    
    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)
    assert_equal ["All come to audi small", "es - All come to audi small"], category_elements.first.first
    assert_equal ["All people should assemble in Vivek audi", "es - All people should assemble in Vivek audi"], category_elements.second.first
  end

  def test_set_category_tree_translations_for_hash
    program = programs(:albers)
    tree = LocalizableContent.relations[LocalizableContent::CAMPAIGN]
    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)
    assert_equal [], [["Campaign Message - Content 8", ""]] - category_elements.third
    data = {
      "Campaign Message - Content 8" => "es - Campaign Message - Content 8"
    }
    set_category_tree_translations(tree, [program.id], data, "es", Program)

    category_elements = get_category_tree_elements(tree, [program.id], "es", Program)

    assert_equal [], [["Campaign Message - Content 8", "es - Campaign Message - Content 8"]] - category_elements.third
  end

  def test_set_klass_translations
    program = programs(:albers)
    data = {
      "All come to audi small" => "es - All come to audi small",
      "All people should assemble in Vivek audi" => "es - All people should assemble in Vivek audi"
    }
    klass_elements = get_klass_elements(Announcement, program.announcements.pluck(:id), "es")
    assert_equal ["All come to audi small",""], klass_elements.first.first
    assert_equal ["All people should assemble in Vivek audi", ""], klass_elements.second.first

    set_klass_translations(Announcement, program.announcements.pluck(:id), data, "es")
    
    klass_elements = get_klass_elements(Announcement, program.announcements.pluck(:id), "es")
    assert_equal ["All come to audi small", "es - All come to audi small"], klass_elements.first.first
    assert_equal ["All people should assemble in Vivek audi", "es - All people should assemble in Vivek audi"], klass_elements.second[0]
  end

  def test_set_klass_translations_by_columns
    program = programs(:albers)
    data = {
      "Drafted Announcement" => "es-Drafted Announcement",
      "All come to audi small" => "es - All come to audi small"
    }
    data2 = {
      "Drafted Announcement" => "es-Drafted Announcement 2",
      "All come to audi small" => "es - All come to audi small 2",
      "All come to audi big announce" => "es - All come to audi big announce"
    }
    assert_equal [["All come to audi small", ""], ["All come to audi big announce", ""], ["expired announcement", ""], ["Drafted Announcement", ""]], get_klass_elements_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")

    set_klass_translations_by_columns(Announcement::Translation, [:title, :body], program.announcements.pluck(:id), :announcement_id, "es", data)

    assert_equal [["All come to audi small", "es - All come to audi small"], ["All come to audi big announce", ""], ["expired announcement", ""], ["Drafted Announcement", "es-Drafted Announcement"]], get_klass_elements_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")

    set_klass_translations_by_columns(Announcement::Translation, [:title, :body], program.announcements.pluck(:id), :announcement_id, "es", data2)

    assert_equal [["All come to audi small", "es - All come to audi small 2"], ["All come to audi big announce", "es - All come to audi big announce"], ["expired announcement", ""], ["Drafted Announcement", "es-Drafted Announcement 2"]], get_klass_elements_by_column(Announcement::Translation, :title, program.announcements.pluck(:id), :announcement_id, "es")
  end

  def test_set_klass_translations_by_columns_including_choice_attr 
    program = programs(:albers)
    survey = program.surveys.first

    data = {
      "Krypton" => "es - Krypton",
      "Earth" => "es - Earth",
      "Smallville" => ""
    }
    data2 = {
      "Krypton" => "es - Krypton 2",
      "Smallville" => "es - Smallville"
    }
    set_klass_translations_by_columns(SurveyQuestion::Translation, [:question_text, :help_text], program.surveys.first.survey_questions.pluck(:id), :common_question_id, "es", data)

    set_klass_translations_by_columns(SurveyQuestion::Translation, [:question_text, :help_text], program.surveys.first.survey_questions.pluck(:id), :common_question_id, "es", data2)
  end

  def test_set_program_settings_translations
    program = programs(:albers)
    data = {
      "Mentor" => "",
      "Meeting" => "es - Meeting",
      "a Mentor" => "es- Mentor",
      "Mentors are professionals who guide and advise mentees in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their mentees." => "[[ es - Mentors ářé ƿřóƒéššíóɳáłš ŵĥó ǧůíďé áɳď áďνíšé mentees íɳ ťĥéíř čářééř ƿáťĥš ťó ĥéłƿ ťĥéɱ šůččééď. Á mentor'š řółé íš ťó íɳšƿířé, éɳčóůřáǧé, áɳď šůƿƿóřť ťĥéíř mentees. ]]"
    }

    set_program_settings_translations(program, "es", data)
    tab_elements_in_program = {
      ProgramsController::SettingsTabs::GENERAL => [["Albers Mentor Program", ""], ["Albers Mentor Program", ""]],
      ProgramsController::SettingsTabs::TERMINOLOGY => [
        ["Mentor", ""], ["Mentors", ""], ["a Mentor", "es- Mentor"],
        ["Student", ""], ["Students", ""], ["a Student", ""],
        ["User", ""], ["Users", ""], ["an User", ""],
        ["Mentoring Connection", ""], ["Mentoring Connections", ""], ["a Mentoring Connection", ""],
        ["Article", ""], ["Articles", ""], ["an Article", ""],
        ["Meeting", "es - Meeting"], ["Meetings", ""], ["a Meeting", ""],
        ["Resource", ""],["Resources", ""], ["a Resource", ""],
        ["Mentoring", ""], ["Mentorings", ""], ["a Mentoring", ""]],
      ProgramsController::SettingsTabs::MEMBERSHIP => [["Mentors are professionals who guide and advise mentees in their career paths to help them succeed. A mentor's role is to inspire, encourage, and support their mentees.", "[[ es - Mentors ářé ƿřóƒéššíóɳáłš ŵĥó ǧůíďé áɳď áďνíšé mentees íɳ ťĥéíř čářééř ƿáťĥš ťó ĥéłƿ ťĥéɱ šůččééď. Á mentor'š řółé íš ťó íɳšƿířé, éɳčóůřáǧé, áɳď šůƿƿóřť ťĥéíř mentees. ]]"],
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

  def test_set_program_settings_objects_translations
    program = programs(:albers)
    settings_sub_category = program.translation_settings_sub_categories.second
    item = get_translatable_objects_program_settings(settings_sub_category[:id], program).first
    translation_elements = get_translation_score_or_elements_for_object(item, "es", program.standalone?, LocalizableContent::PROGRAM_SETTINGS, tab = settings_sub_category[:id], attachment = nil, score = false)
    assert_equal [["Mentor", ""], ["Mentors", ""], ["a Mentor", ""]], translation_elements

    data = {
      "Mentor" => "es - Mentor",
      "Mentors" => "",
      "a Mentor" => "es - a Mentor"
    }
    set_program_settings_objects_translations(item, "es", program.standalone?, LocalizableContent::PROGRAM_SETTINGS, settings_sub_category[:id], data)

    item = get_translatable_objects_program_settings(settings_sub_category[:id], program).first
    translation_elements = get_translation_score_or_elements_for_object(item, "es", program.standalone?, LocalizableContent::PROGRAM_SETTINGS, tab = settings_sub_category[:id], attachment = nil, score = false)
    assert_equal [["Mentor", "es - Mentor"], ["Mentors", ""], ["a Mentor", "es - a Mentor"]], translation_elements

    data2 = {
      "Mentor" => "es - Mentor2",
      "Mentors" => "es - Mentors2",
      "a Mentor" => "es - a Mentor2"
    }
    set_program_settings_objects_translations(item, "es", program.standalone?, LocalizableContent::PROGRAM_SETTINGS, settings_sub_category[:id], data2)

    item = get_translatable_objects_program_settings(settings_sub_category[:id], program).first
    translation_elements = get_translation_score_or_elements_for_object(item, "es", program.standalone?, LocalizableContent::PROGRAM_SETTINGS, tab = settings_sub_category[:id], attachment = nil, score = false)
    assert_equal [["Mentor", "es - Mentor2"], ["Mentors", "es - Mentors2"], ["a Mentor", "es - a Mentor2"]], translation_elements
  end

  def test_def_is_valid_translation

    valid, error_group = is_valid_translation?("{{user_firstname}}, finish signing up today!", "user_firstname, finish signing up today!")
    assert_equal false, valid
    assert_equal [0], error_group

    valid, error_group = is_valid_translation?("<div>hello</div>", "hello</div>")
    assert_equal false, valid
    assert_equal [1], error_group
  end

  def test_get_insert_locale_array
    en_object = CustomizedTerm.all.first.translations.select{|t| t.locale == :en}.first || {}
    locale_object = CustomizedTerm.all.first.translations.select{|t| t.locale == :es}.first || {}
    data = {
      "Mentoring Connection" => "es - Mentoring Connection"
    }
    modify, insert_locale_array, insert_locale_columns = get_insert_locale_array(CustomizedTerm.all.first, [:term, :term_downcase], en_object, locale_object, data, :es)
    assert_equal true, modify
    assert_equal ["customized_term_id", :locale, :term, :term_downcase], insert_locale_columns
    assert_equal [1, :es, "es - Mentoring Connection", nil], insert_locale_array
  end
end