require_relative './../../../../test_helper.rb'
class ImporterTest < ActiveSupport::TestCase
 include SolutionPack::ImporterUtils

  def test_associated_importers
    sp = SolutionPack.new
    sp.program = programs(:albers)

    importer = ProgramImporter.new(sp)
    assert_equal ProgramImporter::AssociatedImporters, importer.associated_importers

    importer.solution_pack.program = programs(:primary_portal)
    assert_equal ProgramImporter::CareerDevAssociatedImporters, importer.associated_importers

    role_importer = RoleImporter.new(importer)
    assert_equal RoleImporter::AssociatedImporters, role_importer.associated_importers

    importer.solution_pack.program = programs(:albers)
    assert_equal RoleImporter::AssociatedImporters, role_importer.associated_importers
  end

  def test_change_in_associated_importers
    expected = {
      ProgramImporter =>
        {
          added: ["GroupClosureReasonImporter", "MentoringModelImporter", "OverviewPagesImporter", "ConnectionQuestionImporter"],
          removed: []
        },
      RoleQuestionImporter =>
        {
          added: ["MatchConfigImporter"],
          removed: []
        },
      SettingsImporter =>
        {
          added: ["CalendarSettingExporter"],
          removed: []
        }
    }
    expected.each do |importer, values|
      assert_equal values[:added], importer::AssociatedImporters - importer::CareerDevAssociatedImporters, "Associated Importers have been added to #{importer.name}"
      assert_equal values[:removed], importer::CareerDevAssociatedImporters - importer::AssociatedImporters, "Associated Importers have been removed from #{importer.name}"
    end
  end

  def test_assoicated_models_to_take_and_skip_for_export_import
    assert_equal ["RoleExporter", "SectionExporter", "ProfileQuestionExporter", "RoleQuestionExporter", "QuestionChoiceExporter", "ConditionalMatchChoiceExporter", "RoleQuestionPrivacySettingExporter"], ProfileQuestion::ImportExportConstants::ExportConstants[:ToInclude] + RoleExporter::AssociatedExporters + SectionExporter::AssociatedExporters + ProfileQuestionExporter::AssociatedExporters + RoleQuestionExporter::AssociatedExporters  - ProfileQuestion::ImportExportConstants::ExportConstants[:ToSkip]

    assert_equal ["RoleImporter", "SectionImporter", "ProfileQuestionImporter", "RoleQuestionImporter", "QuestionChoiceImporter", "ConditionalMatchChoiceImporter", "RoleQuestionPrivacySettingImporter"], ProfileQuestion::ImportExportConstants::ImportConstants[:ToInclude] + RoleImporter::AssociatedImporters + SectionImporter::AssociatedImporters + ProfileQuestionImporter::AssociatedImporters + RoleQuestionImporter::AssociatedImporters  - ProfileQuestion::ImportExportConstants::ImportConstants[:ToSkip]
  end

  def test_profile_quesitons_export_import_in_same_program_with_same_profile_questions
    program = programs(:foster)

    CustomizedTermExporter.any_instance.expects(:export).never
    RolePermissionExporter.any_instance.expects(:export).never
    PermissionExporter.any_instance.expects(:export).never
    MatchConfigExporter.any_instance.expects(:export).never

    solution_pack = SolutionPack.new(program: program)
    file_path = solution_pack.export(
      custom_associated_exporters: [RoleExporter.name, SectionExporter.name],
      skipped_associated_exporters: [MatchConfigExporter.name, CustomizedTermExporter.name, RolePermissionExporter.name],
      return_zip_file: true,
      skip_post_attachment: true
    )

    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(file_path), mimeType)
    program.solution_pack_file = save_content_pack_to_be_imported(attached_file)

    MatchConfigImporter.any_instance.expects(:export).never
    CustomizedTermImporter.any_instance.expects(:export).never
    RolePermissionImporter.any_instance.expects(:export).never
    PermissionImporter.any_instance.expects(:export).never

    assert_no_difference 'ProfileQuestion.count' do
      assert_no_difference 'Section.count' do
        assert_no_difference 'RoleQuestion.count' do
          assert_no_difference 'ConditionalMatchChoice.count' do
            assert_no_difference 'QuestionChoice.count' do
              assert_no_difference 'RoleQuestionPrivacySetting.count' do
                assert_no_difference 'Role.count' do
                  import_solution_pack(
                    program,
                    custom_associated_importers: [RoleImporter.name,SectionImporter.name],
                    skipped_associated_importers: [MatchConfigImporter.name, CustomizedTermImporter.name, RolePermissionImporter.name, PermissionImporter.name]
                  )
                end
              end
            end
          end
        end
      end
    end
    ensure
      FileUtils.rm_rf(file_path) if File.exist?(file_path)
  end

  def test_profile_quesitons_export_import_in_same_program_with_changed_profile_questions
    program = programs(:foster)
    organization = program.organization

    solution_pack = SolutionPack.new(program: program)
    file_path = solution_pack.export(
      custom_associated_exporters: [RoleExporter.name, SectionExporter.name],
      skipped_associated_exporters: [MatchConfigExporter.name, CustomizedTermExporter.name, RolePermissionExporter.name],
      return_zip_file: true,
      skip_post_attachment: true
    )

    section = organization.sections.last(2).first

    assert_difference 'ProfileQuestion.count', -10 do
      assert_difference 'Section.count', -1 do
        assert_difference 'RoleQuestion.count', -15 do
          assert_no_difference 'ConditionalMatchChoice.count' do
            assert_difference 'QuestionChoice.count', -384 do
              assert_no_difference 'RoleQuestionPrivacySetting.count' do
                assert_no_difference 'Role.count' do
                  section.destroy
                end
              end
            end
          end
        end
      end
    end

    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(file_path), mimeType)
    program.solution_pack_file = save_content_pack_to_be_imported(attached_file)

    assert_difference 'ProfileQuestion.count', 10 do
      assert_difference 'Section.count', 1 do
        assert_difference 'RoleQuestion.count', 15 do
          assert_no_difference 'ConditionalMatchChoice.count' do
            assert_difference 'QuestionChoice.count', 384 do
              assert_no_difference 'RoleQuestionPrivacySetting.count' do
                assert_no_difference 'Role.count' do
                  import_solution_pack(
                    program,
                    custom_associated_importers: [RoleImporter.name,SectionImporter.name],
                    skipped_associated_importers: [MatchConfigImporter.name, CustomizedTermImporter.name, RolePermissionImporter.name, PermissionImporter.name]
                  )
                end
              end
            end
          end
        end
      end
    end
    ensure
      FileUtils.rm_rf(file_path) if File.exist?(file_path)
  end

end