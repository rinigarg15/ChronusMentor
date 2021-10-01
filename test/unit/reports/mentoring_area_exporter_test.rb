require_relative './../../test_helper.rb'

class MentoringAreaExporterTest < ActiveSupport::TestCase
  IMPORT_CSV_FILE_NAME = "mentoring_model/mentoring_model_import.csv"

  def test_prawn_generated_pdf_v2_group
    mentor = users(:f_mentor)
    student = users(:mkr_student)
    group = groups(:mygroup)
    program = programs(:albers)
    program.update_attribute(:allow_one_to_many_mentoring, true)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.default_mentoring_model
    MentoringModel::Importer.new(mentoring_model, fixture_file_upload(File.join('files', IMPORT_CSV_FILE_NAME), 'text/csv')).import
    Group::MentoringModelCloner.new(group, program, mentoring_model.reload).copy_mentoring_model_objects

    #deleting the tasks of one goal
    goal = group.mentoring_model_goals.first
    goal.mentoring_model_tasks.destroy_all
    goal.reload
    group.mentoring_model_tasks.reload
    assert_empty goal.mentoring_model_tasks

    ProfilePicture.create(:member => mentor.member, :image => fixture_file_upload(File.join('files', 'test_pic.bmp'), 'image/bmp'))
    rendered_pdf = MentoringAreaExporter.generate_pdf(mentor, group, false)
    pdf_strings = get_pdf_strings(rendered_pdf)

    assert pdf_strings.include? group.program.name

    # header texts
    assert pdf_strings.include? "Summary"
    assert pdf_strings.include? "Goals"
    assert pdf_strings.include? "Tasks"
    assert pdf_strings.include? "Milestones"
    assert pdf_strings.include? "Activity Overview"
    assert pdf_strings.include? "Messages Sent"
    assert pdf_strings.include? "Meetings Attended"
    assert pdf_strings.include? "Survey Responses"
    assert pdf_strings.include? "Messages"
    assert pdf_strings.include? "My Personal Notes"

    #goals
    group.mentoring_model_goals.each do |goal|
      assert pdf_strings.include? goal.title
    end

    #tasks
    group.mentoring_model_tasks.each do |task|
      assert pdf_strings.include? task.title
    end

    #milestones
    assert pdf_strings.include? "1. Orientation"
    assert pdf_strings.include? "2. Getting acquainted: First two weeks"
    assert pdf_strings.include? "3. Settling in: First 90 days"
    assert pdf_strings.include? "4. Becoming adjusted: First 6 months"

    # personal notes
    group.private_notes.owned_by(mentor).each do |note|
      assert pdf_strings.include? note.text
    end

    # scraps
    assert pdf_strings.include? "From: #{mentor.name}"
    assert pdf_strings.include? "From: #{student.name}"
    assert pdf_strings.include? "hello how are you"
  end

  def test_prawn_generated_pdf_feature_dependency
    group = groups(:mygroup)
    group_user = group.members.first
    program = group.program
    assert_false program.mentoring_connections_v2_enabled?
    assert program.allow_private_journals?
    assert_false group.meetings_enabled?
    assert group.scraps_enabled?

    rendered_pdf = MentoringAreaExporter.generate_pdf(group_user, group, false)
    pdf_strings = get_pdf_strings(rendered_pdf)
    assert_false pdf_strings.include? "Goals"
    assert_false pdf_strings.include? "Tasks"
    assert_false pdf_strings.include? "Milestones"
    assert_false pdf_strings.include? "Activity Overview"
    assert_false pdf_strings.include? "Messages Sent"
    assert_false pdf_strings.include? "Meetings Attended"
    assert_false pdf_strings.include? "Survey Responses"
    assert pdf_strings.include? "Messages"

    Program.any_instance.stubs(:mentoring_connections_v2_enabled?).returns(true)
    Program.any_instance.stubs(:allow_private_journals?).returns(false)
    group.stubs(:meetings_enabled?).returns(true)
    group.stubs(:scraps_enabled?).returns(false)

    rendered_pdf = MentoringAreaExporter.generate_pdf(group_user, group, false)
    pdf_strings = get_pdf_strings(rendered_pdf)
    assert_false pdf_strings.include? "Goals"
    assert pdf_strings.include? "Tasks"
    assert_false pdf_strings.include? "Milestones"
    assert pdf_strings.include? "Activity Overview"
    assert_false pdf_strings.include? "Messages Sent"
    assert pdf_strings.include? "Meetings Attended"
    assert pdf_strings.include? "Survey Responses"
    assert_false pdf_strings.include? "Messages"
    assert_false pdf_strings.include? "My Personal Notes"
  end

  def test_get_formatted_time_in_zone
    user1 = users(:f_student)
    user2 = users(:f_mentor)
    user1.member.time_zone = "Asia/Kolkata"
    user1.member.save!
    user2.member.time_zone = "Asia/Kathmandu"
    user2.member.save!
    t = Time.new(2012, 8, 29, 22, 35, 0)

    # Nepal Time is 15 min. ahead of India
    assert_equal "August 29, 2012 at 10:35 PM", MentoringAreaExporter.get_formatted_time_in_zone(t, user1, :full_display_no_day)
    assert_equal "August 29, 2012 at 10:50 PM", MentoringAreaExporter.get_formatted_time_in_zone(t, user2, :full_display_no_day)
  end

  def test_goal_with_manual_based_activity
    mentor = users(:f_mentor)
    student = users(:mkr_student)
    group = groups(:mygroup)
    program = programs(:albers)

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.default_mentoring_model
    MentoringModel::Importer.new(mentoring_model, fixture_file_upload(File.join('files', IMPORT_CSV_FILE_NAME), 'text/csv')).import
    mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    Group::MentoringModelCloner.new(group, program, mentoring_model.reload).copy_mentoring_model_objects

    goal = group.mentoring_model_goals.first
    activity = goal.goal_activities.new(progress_value: 30, message: "some connection activity message to check pdf")
    activity.connection_membership_id = group.mentor_memberships.first.id
    activity.member_id = group.mentor_memberships.first.user.member_id
    activity.save

    rendered_pdf = MentoringAreaExporter.generate_pdf(mentor, group, false)
    pdf_strings = get_pdf_strings(rendered_pdf)

    assert pdf_strings.include? group.program.name

    # header texts
    assert pdf_strings.include? "Summary"
    assert pdf_strings.include? "Goals"
    assert pdf_strings.include? "Tasks"
    assert pdf_strings.include? "Milestones"
    assert pdf_strings.include? "Activity Overview"
    assert pdf_strings.include? "Messages Sent"
    assert pdf_strings.include? "Meetings Attended"
    assert pdf_strings.include? "Survey Responses"
    assert pdf_strings.include? "Messages"
    assert pdf_strings.include? "My Personal Notes"

    #goals
    group.mentoring_model_goals.each do |goal|
      assert pdf_strings.include? goal.title
    end

    assert pdf_strings.include? "some connection activity message to check pdf"

    #tasks
    group.mentoring_model_tasks.each do |task|
      assert pdf_strings.include? task.title
    end

    #milestones
    assert pdf_strings.include? "1. Orientation"
    assert pdf_strings.include? "2. Getting acquainted: First two weeks"
    assert pdf_strings.include? "3. Settling in: First 90 days"
    assert pdf_strings.include? "4. Becoming adjusted: First 6 months"

    # personal notes
    group.private_notes.owned_by(mentor).each do |note|
      assert pdf_strings.include? note.text
    end

    # scraps
    assert pdf_strings.include? "From: #{mentor.name}"
    assert pdf_strings.include? "From: #{student.name}"
    assert pdf_strings.include? "hello how are you"
  end

  def test_file_base_name
    assert_equal "small.jpg", MentoringAreaExporter.class_eval { get_base_name("/tmp/small.jpg?test1=t&test2=t") }
    assert_equal "small.jpg", MentoringAreaExporter.class_eval { get_base_name("https://test.com/small.jpg?test1=t&test2=t") }
    assert_equal "small", File.basename(MentoringAreaExporter.class_eval { get_base_name("/tmp/small.jpg?test1=t&test2=t") }, ".*")
  end

  def test_prawn_generated_pdf_user_details_pre_v1_group
    mentor = users(:f_mentor)
    student = users(:mkr_student)
    group = groups(:mygroup)
    org = programs(:org_primary)
    admin = users(:f_admin)

    # Admin Case: Mentor Exporting PDF
    rendered_pdf = MentoringAreaExporter.generate_pdf(admin, group, false)
    pdf_strings = get_pdf_strings(rendered_pdf)

    assert pdf_strings.include? group.program.name

    group.members.each do |group_member|
      assert pdf_strings.include? group_member.email
      assert pdf_strings.include? group_member.name
    end

    #Mentor Exporting PDF; Student's email question privacy setting: ADMIN_ONLY_VIEWABLE
    email_que = org.email_question.role_questions.find_by(role_id: student.roles.first.id)
    email_que.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    email_que.save!

    rendered_pdf = MentoringAreaExporter.generate_pdf(mentor, group, false)
    pdf_strings = get_pdf_strings(rendered_pdf)

    assert pdf_strings.include? group.program.name

    group.members.each do |group_member|
      assert pdf_strings.include? group_member.name
      if group_member == mentor
        assert pdf_strings.include?(group_member.email)
      else
        assert_false pdf_strings.include?(group_member.email)
      end
    end
  end

  def test_render_image_cell
    user = users(:f_mentor)
    img_cell_options = {
        image_height: 50,
        image_width: 50,
        position: :center,
        vposition: :top,
        rowspan: 3
    }
    profile_pic_cell1, tmp_img_path1 = MentoringAreaExporter.send(:render_image_cell, user, img_cell_options)
    profile_pic_cell2, tmp_img_path2 = MentoringAreaExporter.send(:render_image_cell, user, img_cell_options)
    assert_not_equal profile_pic_cell1, profile_pic_cell2
    assert_not_equal tmp_img_path1, tmp_img_path2
  end

  private

  def get_pdf_strings(rendered_pdf)
    PDF::Inspector::Text.analyze(rendered_pdf).strings.join(" ")
  end
end