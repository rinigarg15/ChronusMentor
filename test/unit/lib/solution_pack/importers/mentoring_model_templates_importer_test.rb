require_relative './../../../../test_helper.rb'

class MentoringModelTemplatesImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_mentoring_model_templates_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    new_program.mentoring_models.destroy_all

    exported_mentoring_model_count = 0
    exported_mentoring_model_titles = []
    mentoring_model_file_path = File.join(IMPORT_CSV_BASE_PATH, "mentoring_model.csv")
    csv_content = fixture_file_upload(mentoring_model_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_mentoring_model_count += 1
      exported_mentoring_model_titles << row["title"]
    end

    #the following arrays contain counts of the different templates in all the mentoring models imported
    #length of each array is equal to the number of mentoring models read from the solution pack, in the present case 1
    exported_goal_template_counts = [4]
    exported_goal_template_titles = [["Familiarize with organizational culture", "Integrate and network", "Role clarity", "Self-efficacy"]]
    exported_milestone_template_counts = [4]
    exported_milestone_template_titles = [["Orientation", "Getting acquainted: First two weeks", "Settling in: First 90 days", "Becoming adjusted: First 6 months"]]
    exported_task_template_counts = [24]
    valid_exported_task_template_counts = [23]
    exported_task_template_titles = [["Face-to-face introduction and a walking tour", "Verify that basic orientation has been completed by HR", "Discuss company overview", "Watch orientation video", "Recap first day", "Introductions to other staff, clarification of training", "Mentee to share learnings so far", "Share learnings", "Complete training on core products", "Review product knowledge", "Review company website and intranet", "Industry intel", "Recap first week experience and answer questions", "Clarify initial work plan & performance expectations", "Shadow mentor for a day", "Set 90-day goals", "Recap week 2 and answer questions", "Recap week 3 and answer questions", "Schedule bi-weekly meeting series for next 3 months", "60-day progress check", "90-day progress check", "Set 6-month goals", "Set intentions for 1-year goals", "test"]]
    valid_exported_task_template_titles = [["Face-to-face introduction and a walking tour", "Verify that basic orientation has been completed by HR", "Discuss company overview", "Watch orientation video", "Recap first day", "Introductions to other staff, clarification of training", "Mentee to share learnings so far", "Share learnings", "Complete training on core products", "Review product knowledge", "Review company website and intranet", "Industry intel", "Recap first week experience and answer questions", "Clarify initial work plan & performance expectations", "Shadow mentor for a day", "Set 90-day goals", "Recap week 2 and answer questions", "Recap week 3 and answer questions", "Schedule bi-weekly meeting series for next 3 months", "60-day progress check", "90-day progress check", "Set 6-month goals", "Set intentions for 1-year goals"]]
    exported_facilitation_template_tasks = [1]
    valid_exported_facilitation_template_tasks = [0]
    exported_object_role_permission_counts = [13]

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_goal_template_counts = new_program.mentoring_models.map{|mm| mm.mentoring_model_goal_templates.count}
    imported_goal_template_titles = new_program.mentoring_models.map{|mm| mm.mentoring_model_goal_templates.collect(&:title)}
    imported_milestone_template_counts = new_program.mentoring_models.map{|mm| mm.mentoring_model_milestone_templates.count}
    imported_milestone_template_titles = new_program.mentoring_models.map{|mm| mm.mentoring_model_milestone_templates.collect(&:title)}
    imported_task_template_counts = new_program.mentoring_models.map{|mm| mm.mentoring_model_task_templates.count}
    imported_task_template_titles = new_program.mentoring_models.map{|mm| mm.mentoring_model_task_templates.collect(&:title)}
    imported_facilitation_template_counts = new_program.mentoring_models.map{|mm| mm.mentoring_model_facilitation_templates.count}
    imported_object_role_permission_counts = new_program.mentoring_models.map{|mm| mm.object_role_permissions.count}

    assert_equal_unordered imported_goal_template_counts, exported_goal_template_counts
    assert_equal_unordered imported_goal_template_titles, exported_goal_template_titles
    assert_equal_unordered imported_milestone_template_counts, exported_milestone_template_counts
    assert_equal_unordered imported_milestone_template_titles, exported_milestone_template_titles
    assert_equal_unordered imported_task_template_counts, valid_exported_task_template_counts
    len = exported_task_template_titles.first.size - 1 
    assert_equal_unordered imported_task_template_titles,  valid_exported_task_template_titles
    assert_equal_unordered imported_facilitation_template_counts, valid_exported_facilitation_template_tasks
    assert_equal_unordered imported_object_role_permission_counts, exported_object_role_permission_counts

    role_file_path = File.join(solution_pack.base_directory_path, "role-imported.csv")
    mentoring_model_file_path = File.join(solution_pack.base_directory_path, "mentoring_model-imported.csv")
    object_role_permission_file_path = File.join(solution_pack.base_directory_path, "object_role_permission-imported.csv")
    mentoring_model_link_file_path = File.join(solution_pack.base_directory_path, "mentoring_model_link-imported.csv")
    assert File.exists?(role_file_path)
    assert File.exists?(mentoring_model_file_path)
    assert File.exists?(object_role_permission_file_path)
    assert File.exists?(mentoring_model_link_file_path)

    delete_base_dir_for_import
  end

  def test_mentoring_model_imports_with_invalid_surveys_present
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    new_program.mentoring_models.destroy_all

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    importer = ProgramImporter.new(solution_pack).import
    assert_equal solution_pack.custom_errors.size, 2
    assert_equal solution_pack.custom_errors.collect(&:type).uniq, [SolutionPack::Error::TYPE::MentoringModel]

    new_program.reload
    assert_equal new_program.mentoring_models.first.mentoring_model_task_templates.size, 23
    assert_equal new_program.mentoring_models.first.mentoring_model_facilitation_templates.size, 0
  end
end