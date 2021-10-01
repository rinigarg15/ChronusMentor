require_relative './../../../../test_helper.rb'

class ProgramExporterTest < ActiveSupport::TestCase

  def test_program_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    RoleExporter.any_instance.expects(:export).once
    CustomizedTermExporter.any_instance.expects(:export).once
    SettingsExporter.any_instance.expects(:export).once
    SurveyExporter.any_instance.expects(:export).once
    ConnectionQuestionExporter.any_instance.expects(:export).once
    ForumExporter.any_instance.expects(:export).once
    SectionExporter.any_instance.expects(:export).once
    AdminViewExporter.any_instance.expects(:export).once
    AbstractCampaignExporter.any_instance.expects(:export).once
    MentoringModelExporter.any_instance.expects(:export).once
    CkeditorAssetExporter.any_instance.expects(:export).once
    ResourceExporter.any_instance.expects(:export).once
    MailerTemplateExporter.any_instance.expects(:export).once
    GroupClosureReasonExporter.any_instance.expects(:export).once
    OverviewPagesExporter.any_instance.expects(:export).once
    section_ids = []

    solution_pack = create_solution_pack(program)
    export_program(program, solution_pack)

    assert_equal_unordered @program_exporter.objs, [program]
    assert_equal @program_exporter.program, program
    assert_equal @program_exporter.solution_pack, solution_pack
  ensure
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_portal_export
    program = programs(:primary_portal)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    RoleExporter.any_instance.expects(:export).once
    CustomizedTermExporter.any_instance.expects(:export).once
    SettingsExporter.any_instance.expects(:export).once
    SurveyExporter.any_instance.expects(:export).once
    ForumExporter.any_instance.expects(:export).once
    SectionExporter.any_instance.expects(:export).once
    AdminViewExporter.any_instance.expects(:export).once
    AbstractCampaignExporter.any_instance.expects(:export).once
    MentoringModelExporter.any_instance.expects(:export).never
    CkeditorAssetExporter.any_instance.expects(:export).once
    ResourceExporter.any_instance.expects(:export).once
    MailerTemplateExporter.any_instance.expects(:export).once
    GroupClosureReasonExporter.any_instance.expects(:export).never
    section_ids = []

    solution_pack = create_solution_pack(program)
    export_program(program, solution_pack)

    assert_equal_unordered @program_exporter.objs, [program]
    assert_equal @program_exporter.program, program
    assert_equal @program_exporter.solution_pack, solution_pack
  ensure
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_sales_demo_program_export
    program = programs(:albers)
    PostExporter.any_instance.expects(:export).once
    solution_pack = create_solution_pack(program, true)
    export_program(program, solution_pack)
  end

  def test_non_sales_demo_program_export
    program = programs(:albers)
    TopicExporter.any_instance.expects(:export).never
    solution_pack = create_solution_pack(program)
    export_program(program, solution_pack)
  end

  private

  def create_solution_pack(program, is_sales_demo = false)
    solution_pack = SolutionPack.new(program: program, created_by: "need", is_sales_demo: is_sales_demo)
    solution_pack.initialize_solution_pack_for_export
    solution_pack
  end

  def export_program(program, solution_pack)
    @program_exporter = ProgramExporter.new(program, solution_pack)
    @program_exporter.export
  end

end