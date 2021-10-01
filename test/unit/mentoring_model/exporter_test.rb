require_relative './../../test_helper.rb'

require 'fileutils'

class MentoringModel::ExporterTest < ActiveSupport::TestCase
  IMPORT_CSV_FILE_NAME = "mentoring_model/mentoring_model_import.csv"
  IMPORT_TEMP_CSV_FILE_NAME = "mentoring_model/mentoring_model_import_temp.csv"

  TASK_GOALS_IMPORT_CSV_FILE_NAME = "mentoring_model/tasks_goals_import.csv"
  TASK_GOALS_IMPORT_TEMP_CSV_FILE_NAME = "mentoring_model/tasks_goals_import_temp.csv"

  IMPORT_CSV_FILE = "test/fixtures/files/#{IMPORT_CSV_FILE_NAME}"
  IMPORT_TEMP_CSV_FILE = "test/fixtures/files/#{IMPORT_TEMP_CSV_FILE_NAME}"
  EXPORT_CSV_FILE = "tmp/mentoring_model_export.csv"
  EXPORT_CSV_FILE_CHECK = "tmp/mentoring_model_export_check.csv"

  TASK_GOALS_IMPORT_CSV_FILE = "test/fixtures/files/#{TASK_GOALS_IMPORT_CSV_FILE_NAME}"
  TASK_GOALS_IMPORT_TEMP_CSV_FILE = "test/fixtures/files/#{TASK_GOALS_IMPORT_TEMP_CSV_FILE_NAME}"
  TASK_GOALS_EXPORT_CSV_FILE = "tmp/tasks_goals_export.csv"

  def setup
    super
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
  end

  def test_export_file
    assert import_file(IMPORT_CSV_FILE_NAME)

    export_file(IMPORT_TEMP_CSV_FILE)
    @mentoring_model.object_role_permissions.destroy_all
    assert import_file(IMPORT_TEMP_CSV_FILE_NAME)

    export_file(EXPORT_CSV_FILE)
    assert FileUtils.compare_file(IMPORT_TEMP_CSV_FILE, EXPORT_CSV_FILE)
    p=@mentoring_model.program
    p.roles.each do |role|
      if role.customized_term[:term]=="Student"
        role.customized_term[:term]="Coachee"
        role.customized_term.save!
      end
    end                           #changecustomterm
    export_file(EXPORT_CSV_FILE_CHECK)
    assert !FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    p.roles.each do |role|
      if role.customized_term[:term]=="Coachee"
        role.customized_term[:term]="Student"
        role.customized_term.save!
      end
    end
    export_file(EXPORT_CSV_FILE_CHECK)
    assert FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    default_forum_help_text = "Welcome to the discussion board! Ask questions, debate ideas, and share articles. You can follow conversations you like, expand a conversation to view the posts, or get a new conversation started!"
    @mentoring_model.forum_help_text = "Different Help text"
    export_file(EXPORT_CSV_FILE_CHECK)
    assert !FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    @mentoring_model.forum_help_text = default_forum_help_text
    export_file(EXPORT_CSV_FILE_CHECK)
    assert FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    @mentoring_model.allow_messaging = false
    export_file(EXPORT_CSV_FILE_CHECK)
    assert !FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    @mentoring_model.allow_messaging = true
    export_file(EXPORT_CSV_FILE_CHECK)
    assert FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)


    @mentoring_model.allow_forum = true
    export_file(EXPORT_CSV_FILE_CHECK)
    assert !FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    @mentoring_model.allow_forum = false
    export_file(EXPORT_CSV_FILE_CHECK)
    assert FileUtils.compare_file(EXPORT_CSV_FILE_CHECK, EXPORT_CSV_FILE)

    @mentoring_model.object_role_permissions.destroy_all
    assert import_file(TASK_GOALS_IMPORT_CSV_FILE_NAME)

    export_file(TASK_GOALS_IMPORT_TEMP_CSV_FILE)
    @mentoring_model.object_role_permissions.destroy_all
    assert import_file(TASK_GOALS_IMPORT_TEMP_CSV_FILE_NAME)

    export_file(TASK_GOALS_EXPORT_CSV_FILE)
    assert FileUtils.compare_file(TASK_GOALS_IMPORT_TEMP_CSV_FILE, TASK_GOALS_EXPORT_CSV_FILE)
  end

  private

  def import_file(filename)
    stream = fixture_file_upload(File.join('files', filename), 'text/csv')
    importer = MentoringModel::Importer.new(@mentoring_model, stream)
    importer.import.successful?
  end

  def export_file(file)
    exporter = MentoringModel::Exporter.new
    exporter.export(@mentoring_model, file)
  end
end