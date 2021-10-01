require_relative './../../test_helper.rb'

class GroupViewsHelperTest < ActionView::TestCase
	include AdminViewsHelper

	def test_format_filetype_user_answer_for_group_mentoring
		answer = [["some_file_name", "some_url"]]
		names = ["some_name"]
		content = format_filetype_user_answer_for_group_mentoring(answer, names)
		assert_equal "<ul><li><span class=\"strong\">some_name - </span><a target=\"_blank\" href=\"some_url\">some_file_name</a></li></ul>", content
		content = format_filetype_user_answer_for_group_mentoring(answer, names, :for_csv => true)
		assert_equal "some_name - some_file_name\n", content
		answer = [["some_file_name", "some_url"], ["some_file_name1", "some_url1"]]
		names = ["some_name", "some_name1"]
		content = format_filetype_user_answer_for_group_mentoring(answer, names)
		assert_equal "<ul><li><span class=\"strong\">some_name - </span><a target=\"_blank\" href=\"some_url\">some_file_name</a></li><li><span class=\"strong\">some_name1 - </span><a target=\"_blank\" href=\"some_url1\">some_file_name1</a></li></ul>", content
		content = format_filetype_user_answer_for_group_mentoring(answer, names, :for_csv => true)
		assert_equal "some_name - some_file_name\nsome_name1 - some_file_name1\n", content
	end

	def test_format_filetype_user_answer
		#Multiple mentor/mentee case
		answer = [["some_file_name", "some_url"], ["some_file_name1", "some_url1"]]
		names = ["some_name", "some_name1"]
		content = format_filetype_user_answer(answer, names, :for_csv => false)
		assert_equal "<ul><li><span class=\"strong\">some_name - </span><a target=\"_blank\" href=\"some_url\">some_file_name</a></li><li><span class=\"strong\">some_name1 - </span><a target=\"_blank\" href=\"some_url1\">some_file_name1</a></li></ul>", content
		content = format_filetype_user_answer_for_group_mentoring(answer, names, :for_csv => true)
		assert_equal "some_name - some_file_name\nsome_name1 - some_file_name1\n", content

		#Single mentor/mentee case
		answer = [["some_file_name", "some_url"]]
		names = ["some_name"]
		content = format_filetype_user_answer(answer, names, :for_csv => false)
		assert_equal "<a target=\"_blank\" href=\"some_url\">some_file_name</a>", content

		content = format_filetype_user_answer(answer, names, :for_csv => true)
		assert_equal 'some_file_name', content

		answer = [[]]
		names = []
		content = format_filetype_user_answer(answer, names, :for_csv => false)
		assert_equal '', content

		content = format_filetype_user_answer(answer, names, :for_csv => true)
		assert_equal '', content
	end

	def test_format_education_user_answer_for_group_mentoring
    group_view = programs(:albers).group_view
    column = group_view.group_view_columns.first
    profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false})
    edu_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EDUCATION}.first
    column.update_attributes!(:column_key => nil, :profile_question => edu_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)

		#format education for one user answer for html
    answer = [[["Indian college", "Arts", "Computer Engineering", 2006]]]
    names = ["some_name"]
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question)
    assert_equal "<ul><li><span class=\"strong\">some_name - </span>Indian college, Arts, Computer Engineering, 2006</li></ul>", content

    #format education for one user answer for csv
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => true)
    assert_equal "some_name - Indian college, Arts, Computer Engineering, 2006\n", content

    #format education for one user multiple answer for html
    answer = [[["Indian college", "Arts", "Computer Engineering", 2006], ["American boys school", "Science", "Mechanical", 2003]]]
    names = ["some_name"]
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question)
    assert_equal "<ul><li><span class=\"strong\">some_name - </span>Indian college, Arts, Computer Engineering, 2006<br/>American boys school, Science, Mechanical, 2003</li></ul>", content

    #format education for one user multiple answer for csv
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => true)
    assert_equal "some_name - Indian college, Arts, Computer Engineering, 2006\nAmerican boys school, Science, Mechanical, 2003\n", content

    #format education for multiple user single answer for html
    answer = [[["Indian college", "Arts", "Computer Engineering", 2006]], [["American boys school", "Science", "Mechanical", 2003]]]
    names = ["some_name", "some_name1"]
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question)
    assert_equal "<ul><li><span class=\"strong\">some_name - </span>Indian college, Arts, Computer Engineering, 2006</li><li><span class=\"strong\">some_name1 - </span>American boys school, Science, Mechanical, 2003</li></ul>", content

    #format education for multiple user single answer for html
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => true)
    assert_equal "some_name - Indian college, Arts, Computer Engineering, 2006\nsome_name1 - American boys school, Science, Mechanical, 2003\n", content

    #format education for multiple user multiple answer for html
    answer = [[["Indian college", "Arts", "Computer Engineering", 2006], ["Guindy"]], [["American boys school", "Science", "Mechanical", 2003], ["Mumbai"]]]
    names = ["some_name", "some_name1"]
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => false)
    assert_equal "<ul><li><span class=\"strong\">some_name - </span>Indian college, Arts, Computer Engineering, 2006<br/>Guindy</li><li><span class=\"strong\">some_name1 - </span>American boys school, Science, Mechanical, 2003<br/>Mumbai</li></ul>", content

    #format education for multiple user multiple answer for csv
    content = format_education_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => true)
    assert_equal "some_name - Indian college, Arts, Computer Engineering, 2006\nGuindy\nsome_name1 - American boys school, Science, Mechanical, 2003\nMumbai\n", content
	end

	def test_format_education_user_answer
    group_view = programs(:albers).group_view
    column = group_view.group_view_columns.first
    profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false})
    edu_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EDUCATION}.first
    column.update_attributes!(:column_key => nil, :profile_question => edu_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)

		answer = [[["Indian college", "Arts", "Computer Engineering", 2006]]]
		content = format_education_user_answer(answer, [], column.profile_question)
		assert_equal "Indian college, Arts, Computer Engineering, 2006", content
		content = format_education_user_answer(answer, [], column.profile_question, :for_csv => true)
		assert_equal "Indian college, Arts, Computer Engineering, 2006", content

		answer = [[["Indian college", "Arts", "Computer Engineering", 2006], ["Guindy"]]]
		content = format_education_user_answer(answer, [], column.profile_question, :for_csv => false)
		assert_equal "Indian college, Arts, Computer Engineering, 2006<br/>Guindy", content
		content = format_education_user_answer(answer, [], column.profile_question, :for_csv => true)
		assert_equal "Indian college, Arts, Computer Engineering, 2006\nGuindy", content

		#format education for multiple user multiple answer for html
    answer = [[["Indian college", "Arts", "Computer Engineering", 2006], ["Guindy"]], [["American boys school", "Science", "Mechanical", 2003], ["Mumbai"]]]
    names = ["some_name", "some_name1"]
    content = format_education_user_answer(answer, names, column.profile_question, :for_csv => false)
    assert_equal "<ul><li><span class=\"strong\">some_name - </span>Indian college, Arts, Computer Engineering, 2006<br/>Guindy</li><li><span class=\"strong\">some_name1 - </span>American boys school, Science, Mechanical, 2003<br/>Mumbai</li></ul>", content

    #format education for multiple user multiple answer for csv
    content = format_education_user_answer(answer, names, column.profile_question, :for_csv => true)
    assert_equal "some_name - Indian college, Arts, Computer Engineering, 2006\nGuindy\nsome_name1 - American boys school, Science, Mechanical, 2003\nMumbai\n", content
	end

	def test_format_experience_user_answer_for_group_mentoring
    group_view = programs(:albers).group_view
    column = group_view.group_view_columns.first
    profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false})
    exp_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EXPERIENCE}.first
    column.update_attributes!(:column_key => nil, :profile_question => exp_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)

		#single answer for html
		answer = [[["Chief Software Architect And Programming Lead", 1990, 1995, "Mannar"], ["Lead Developer", 1990, 1995, "Microsoft"]],[[]]]
		names = ["some_name",""]
		content = format_experience_user_answer_for_group_mentoring(answer, names, column.profile_question)
		assert_equal "<ul><li><span class=\"strong\">some_name - </span>Chief Software Architect And Programming Lead, 1990&ndash;1995, Mannar<br/>Lead Developer, 1990&ndash;1995, Microsoft</li></ul>", content

		#single answer for csv
		content = format_experience_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => true)
		assert_equal "some_name - Chief Software Architect And Programming Lead, 1990-1995, Mannar\nLead Developer, 1990-1995, Microsoft\n", content

		#multiple answer for html
		answer = [[["Chief Software Architect And Programming Lead", 1990, 1995, "Mannar"], ["Lead Developer", 1990, 1995, "Microsoft"]],[["Product Architect", 2010, 0, "Chronus"]]]
		names = ["some_name","some_name1"]
		content = format_experience_user_answer_for_group_mentoring(answer, names, column.profile_question)
		assert_equal '<ul><li><span class="strong">some_name - </span>Chief Software Architect And Programming Lead, 1990&ndash;1995, Mannar<br/>Lead Developer, 1990&ndash;1995, Microsoft</li><li><span class="strong">some_name1 - </span>Product Architect, 2010&ndash;current, Chronus</li></ul>', content

		#single answer for csv
		content = format_experience_user_answer_for_group_mentoring(answer, names, column.profile_question, :for_csv => true)
		assert_equal "some_name - Chief Software Architect And Programming Lead, 1990-1995, Mannar\nLead Developer, 1990-1995, Microsoft\nsome_name1 - Product Architect, 2010-current, Chronus\n", content
	end

	def test_format_experience_user_answer
    group_view = programs(:albers).group_view
    column = group_view.group_view_columns.first
    profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false})
    exp_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EXPERIENCE}.first
    column.update_attributes!(:column_key => nil, :profile_question => exp_ques, :ref_obj_type => GroupViewColumn::ColumnType::USER)

		answer = [[["Chief Software Architect And Programming Lead", 1990, 1995, "Mannar"], ["Lead Developer", 1990, 1995, "Microsoft"]]]
		names = ["some_name"]
		content = format_experience_user_answer(answer, names, column.profile_question, options = {})
		assert_equal "Chief Software Architect And Programming Lead, 1990&ndash;1995, Mannar<br/>Lead Developer, 1990&ndash;1995, Microsoft", content

		content = format_experience_user_answer(answer, names, column.profile_question, :for_csv => true)
		assert_equal "Chief Software Architect And Programming Lead, 1990-1995, Mannar\nLead Developer, 1990-1995, Microsoft", content

		answer = [[["Chief Software Architect And Programming Lead", 1990, 1995, "Mannar"], ["Lead Developer", 1990, 1995, "Microsoft"]], [[]]]
		names = ["some_name", ""]
		GroupViewsHelperTest.any_instance.expects(:format_experience_user_answer_for_group_mentoring).times(1)
		content = format_experience_user_answer(answer, names, column.profile_question, :for_csv => true)
	end

  def test_format_simple_user_answer_for_group_mentoring
    #single user, single answer
    answer = ["text",""]
    names = ["some_name", "some_name1"]
    content = format_simple_user_answer_for_group_mentoring(answer, names)
    assert_equal '<ul><li><span class="strong">some_name - </span>text</li></ul>', content

    content = format_simple_user_answer_for_group_mentoring(answer, names, :for_csv => true)
    assert_equal "some_name - text\n", content

    #single user, multiple answer
    answer = ["text","text1"]
    names = ["some_name", "some_name1"]
    content = format_simple_user_answer_for_group_mentoring(answer, names)
    assert_equal '<ul><li><span class="strong">some_name - </span>text</li><li><span class="strong">some_name1 - </span>text1</li></ul>', content

    content = format_simple_user_answer_for_group_mentoring(answer, names, :for_csv => true)
    assert_equal "some_name - text\nsome_name1 - text1\n", content

    answer = ["'text1, text2',text3","'text4, text5',text6"]
    names = ["some_name", "some_name1"]
    content = format_simple_user_answer_for_group_mentoring(answer, names, :for_csv => true)
    assert_equal "some_name - 'text1, text2',text3\nsome_name1 - 'text4, text5',text6\n", content
  end

  def test_format_simple_user_answer
    answer = ["text"]
    names = ["some_name"]
    assert_equal "text", format_simple_user_answer(answer, names)
    assert_equal "text", format_simple_user_answer(answer, names, for_csv: true)

    answer = ["Answer for question about me"]
    content = format_simple_user_answer(answer, names, for_csv: false, truncate_size: 10)
    assert_select_helper_function "a.cjs_see_more_link", content, text: "show more »"
    assert_select_helper_function "a.cjs_see_less_link", content, text: "« show less"
    assert_match answer[0], content
    assert_match "Answer...", content

    answer = ["text", "text1"]
    names = ["some_name", "some_name1"]
    GroupViewsHelperTest.any_instance.expects(:format_simple_user_answer_for_group_mentoring).times(1)
    format_simple_user_answer(answer, names, for_csv: true)
  end

  def test_format_user_answer_email
    user = users(:f_mentor)
    answer = []

    group_view = programs(:albers).group_view
    column = group_view.group_view_columns.first
    profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: true})
    email_ques = profile_questions.select{|q| q.question_type == ProfileQuestion::Type::EMAIL}.first

    content = get_user_answer(answer, email_ques, user.member)

    assert_equal "robert@example.com", content
  end

  def test_format_user_answer_select_or_choice_based
    question = profile_questions(:student_multi_choice_q)
    member = members(:f_student)
    answer = ProfileAnswer.new(:profile_question => question, :ref_obj => member)
    answer.answer_value = ["Stand", "Walk"]
    answer.save!

    content = get_user_answer(answer, question, member)
    assert_equal "Stand, Walk", content

    run_in_another_locale(:"fr-CA") do
        assert_equal "Supporter, Marcher", get_user_answer(answer, question, member)
    end
  end

  def test_format_list_answer
    column = GroupViewColumn.first

    assert_equal GroupViewColumn::ColumnType::NONE, column.ref_obj_type
    content = format_list_answer('some_value', [], column)
    assert_equal 'some_value', content

    column.update_attribute(:ref_obj_type, GroupViewColumn::ColumnType::GROUP)
    GroupViewsHelperTest.any_instance.expects(:format_group_question_answer).once.with(['some_value'], column, {})
    format_list_answer(['some_value'], ['some_name'], column)

    column.update_attribute(:ref_obj_type, GroupViewColumn::ColumnType::USER)
    GroupViewsHelperTest.any_instance.expects(:format_user_answers).once.with(['some_value'], ['some_name'], column.profile_question, {})
    format_list_answer(['some_value'], ['some_name'], column)
  end

  def test_format_group_question_answer
    con_ques = Connection::Question.create(:program => programs(:albers), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    column = GroupViewColumn.first

    content = format_group_question_answer(["some_file.txt", "/somefile"], column, options = {})
    assert_equal ["some_file.txt", "/somefile"], content

    column.update_attributes(:connection_question_id => con_ques.id, :ref_obj_type => GroupViewColumn::ColumnType::GROUP)
    content = format_group_question_answer(["some_file.txt", "/somefile"], column, options = {})
    assert_equal ["some_file.txt", "/somefile"], content

    con_ques = Connection::Question.create(:program => programs(:albers), :question_type => CommonQuestion::Type::FILE, :question_text => "Whats your age?")
    column.update_attributes(:connection_question_id => con_ques.id, :ref_obj_type => GroupViewColumn::ColumnType::GROUP)
    content = format_group_question_answer(["some_file.txt", "/somefile"], column, options = {})
    assert_equal "<a target=\"_blank\" href=\"/somefile\">some_file.txt</a>", content
  end

  def test_format_name_for_group_mentoring
  	assert_equal "some_name - ", format_name_for_group_mentoring("some_name", :for_csv => true)
  	assert_equal "<span class=\"strong\">some_name - </span>", format_name_for_group_mentoring("some_name")
  end

  def test_active_since_in_get_default_answer_for_csv
    program = programs(:albers)
    group = create_group(program: program)

    active_since_index_tab_0 = program.group_view.get_group_view_columns(0).collect(&:column_key).index("Active_since")
    active_since_column_tab_0 = program.group_view.get_group_view_columns(0)[active_since_index_tab_0]
    assert_match /ago/, get_default_answer(group, active_since_column_tab_0, false)
    assert_no_match /ago/, get_default_answer(group, active_since_column_tab_0, true)
  end

  def test_start_date_in_get_default_answer
    Time.zone = "Asia/Kolkata"
    
    program = programs(:pbe)
    group = groups(:group_pbe)

    current_time = Time.now.beginning_of_day + 12.hours
    group.update_attribute(:start_date, current_time)

    group_view = program.group_view

    group_view_column = group_view.group_view_columns.find_by(column_key: GroupViewColumn::Columns::Key::START_DATE)

    assert_equal DateTime.localize(current_time, format: :short), get_default_answer(group, group_view_column, false)
  end

  def test_proposed_and_rejected_tab_in_get_default_answer_for_csv
    p = programs(:pbe)
    group_view = p.group_view
    GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::PROPOSED_BY, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::PROPOSED_AT, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::REJECTED_BY, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::REJECTED_AT, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)

    mentor = users(:f_mentor_pbe)
    student = users(:f_student_pbe)
    admin = users(:f_admin_pbe)
    group = create_group(:students => [student], :mentor => mentor, :program => p, :status => 5, :created_by => admin)
    p.roles.find_by(name: RoleConstants::STUDENT_NAME).add_permission(RolePermission::PROPOSE_GROUPS)

    proposed_by_index_tab_5 = p.group_view.get_group_view_columns(5).collect(&:column_key).index("proposed_by")
    proposed_at_index_tab_5 = p.group_view.get_group_view_columns(5).collect(&:column_key).index("proposed_at")
    proposed_by_column_tab_5 = p.group_view.get_group_view_columns(5)[proposed_by_index_tab_5]
    proposed_at_column_tab_5 = p.group_view.get_group_view_columns(5)[proposed_at_index_tab_5]
    rejected_by_index_tab_5 = p.group_view.get_group_view_columns(5).collect(&:column_key).index("rejected_by")
    rejected_at_index_tab_5 = p.group_view.get_group_view_columns(5).collect(&:column_key).index("rejected_at")

    assert_match /Freakin/, get_default_answer(group, proposed_by_column_tab_5, false)
    assert_match /ago/, get_default_answer(group, proposed_at_column_tab_5, false)
    assert_match /Freakin/, get_default_answer(group, proposed_by_column_tab_5, true)
    assert_no_match /ago/, get_default_answer(group, proposed_at_column_tab_5, true)
    assert_nil rejected_by_index_tab_5
    assert_nil rejected_at_index_tab_5

    #Rejecting the group
    group.update_attributes(:closed_by => admin, :closed_at => Time.now(), :termination_reason => "Closing", :status => Group::Status::REJECTED)

    proposed_by_index_tab_6 = p.group_view.get_group_view_columns(6).collect(&:column_key).index("proposed_by")
    proposed_at_index_tab_6 = p.group_view.get_group_view_columns(6).collect(&:column_key).index("proposed_at")
    proposed_by_column_tab_6 = p.group_view.get_group_view_columns(6)[proposed_by_index_tab_6]
    proposed_at_column_tab_6 = p.group_view.get_group_view_columns(6)[proposed_at_index_tab_6]
    rejected_by_index_tab_6 = p.group_view.get_group_view_columns(6).collect(&:column_key).index("rejected_by")
    rejected_at_index_tab_6 = p.group_view.get_group_view_columns(6).collect(&:column_key).index("rejected_at")
    rejected_by_column_tab_6 = p.group_view.get_group_view_columns(6)[rejected_by_index_tab_6]
    rejected_at_column_tab_6 = p.group_view.get_group_view_columns(6)[rejected_at_index_tab_6]

    assert_match /Freakin/, get_default_answer(group, proposed_by_column_tab_5, false)
    assert_match /ago/, get_default_answer(group, proposed_at_column_tab_5, false)
    assert_match /Freakin/, get_default_answer(group, proposed_by_column_tab_5, true)
    assert_no_match /ago/, get_default_answer(group, proposed_at_column_tab_5, true)
    assert_match /Freakin/, get_default_answer(group, rejected_by_column_tab_6, false)
    assert_match /ago/, get_default_answer(group, rejected_at_column_tab_6, false)
    assert_match /Freakin/, get_default_answer(group, rejected_by_column_tab_6, true)
    assert_no_match /ago/, get_default_answer(group, rejected_at_column_tab_6, true)
  end

  def test_group_view_edit_column_mapper
    assert_equal "name:default", group_view_edit_column_mapper("name", "default")
  end

  def test_populate_group_view_default_options
    @current_program = programs(:albers)
    @current_organization = programs(:albers).organization
    mentor_role_id = @current_program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    group_view = programs(:albers).group_view
    assert_match /<option selected=\"selected\" value=\"default:name\">Mentoring Connection Name<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)
    assert_match /<option selected=\"selected\" value=\"default:members:#{mentor_role_id}\">Mentor<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)
    @current_program.group_view.group_view_columns.find_by(column_key: GroupViewColumn::Columns::Key::NAME).destroy
    assert_match /<option value=\"default:name\">Mentoring Connection Name<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)

    assert_match /<option selected=\"selected\" value=\"default:Closed_by\">Closed by<\/option>/, populate_group_view_default_options(group_view, Group::Status::CLOSED)
    assert_match /<option selected=\"selected\" value=\"default:Closed_on\">Closed on<\/option>/, populate_group_view_default_options(group_view, Group::Status::CLOSED)

    assert_no_match /<option selected=\"selected\" value=\"default:Closed_by\">Closed on<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)
    assert_no_match /<option selected=\"selected\" value=\"default:Closed_on\">Closed on<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)

    @current_program.group_view.group_view_columns.find_by(column_key: GroupViewColumn::Columns::Key::CLOSED_BY).destroy

    assert_match /<option value=\"default:Closed_by\">Closed by<\/option>/, populate_group_view_default_options(group_view, Group::Status::CLOSED)
    assert_no_match /<option value=\"default:Closed_by\">Closed by<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)

    @current_program.group_view.group_view_columns.find_by(column_key: GroupViewColumn::Columns::Key::CLOSED_ON).destroy
    assert_match /<option value=\"default:Closed_on\">Closed on<\/option>/, populate_group_view_default_options(group_view, Group::Status::CLOSED)
    assert_no_match /<option value=\"default:Closed_on\">Closed on<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)

    @current_program = programs(:pbe)
    @current_organization = programs(:pbe).organization
    group_view = programs(:pbe).group_view
    mentor_role_id = programs(:pbe).roles.where(name: RoleConstants::MENTOR_NAME).first.id
    teacher_role_id = programs(:pbe).roles.where(name: RoleConstants::TEACHER_NAME).first.id

    assert_match /<option value=\"default:slots_taken:#{teacher_role_id}\">Number of slots taken \(Teacher\)<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)
    assert_match /<option selected=\"selected\" value=\"default:slots_taken:#{mentor_role_id}\">Number of slots taken \(Mentor\)<\/option>/, populate_group_view_default_options(group_view, Group::Status::ACTIVE)
  end

  def test_populate_group_view_user_options
    group_view = programs(:albers).group_view
    mentor_role = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentor_profile_questions = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME], {default: false, skype: false, fetch_all: true})[0..1]
    assert_equal "<option value=\"#{mentor_role.id}:3\">Location</option>\n<option value=\"#{mentor_role.id}:4\">Phone</option>", populate_group_view_user_options(group_view.group_view_columns, mentor_role, mentor_profile_questions)
  end

  def test_populate_group_view_connection_options
    group_view = programs(:albers).group_view
    q_ids = programs(:albers).connection_questions.collect(&:id)
    assert_equal "<option value=\"connection:#{q_ids[0]}\">Funding Value</option>\n<option value=\"connection:#{q_ids[1]}\">Required Connection Question</option>\n<option value=\"connection:#{q_ids[2]}\">Industry</option>\n<option value=\"connection:#{q_ids[3]}\">Scope</option>", populate_group_view_connection_options(group_view.group_view_columns, programs(:albers).connection_questions)
  end

  def test_get_default_answer
    organization = programs(:org_primary)
    program = programs(:albers)
    group = groups(:group_2)
    group_view = programs(:albers).group_view
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::GOALS_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)

    assert_equal "No Goals Yet.", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_goal_progress
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    create_mentoring_model_goal(group_id: group.id)
    create_mentoring_model_goal(group_id: group.id)
    group_view = programs(:albers).group_view
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::GOALS_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "Awesome Title (0%)<br />Awesome Title (0%)", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_survey_responses
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    admin_role = group.program.roles.with_name(RoleConstants::ADMIN_NAME)
    group.stubs(:can_manage_mm_engagement_surveys?).with(admin_role).returns(true)
    group_view = programs(:albers).group_view
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::SURVEY_RESPONSES, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal 0, get_default_answer(group, default_column, true)

    program = group.program
    survey = program.surveys.find_by(name: "Partnership Effectiveness")
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attributes(:should_sync => true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_task_template
    tem_task1.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => program.roles.with_name([RoleConstants::MENTOR_NAME]).first })
    tem_task2 = create_mentoring_model_task_template
    tem_task2.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => program.roles.with_name([RoleConstants::STUDENT_NAME]).first })

    response_id =  SurveyAnswer.maximum(:response_id).to_i + 1
    group.memberships.each do |membership|
      task = group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, connection_membership_id: membership.id).first
      task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
        ans = task.survey_answers.new(:user_id => membership.user_id, :response_id => response_id, :answer_text => "lorem ipsum", :last_answered_at => Time.now.utc)
        ans.survey_question = ques
        ans.save!
      end
      response_id += 1
    end
    assert_equal 2, get_default_answer(group, default_column, true)

    admin_role = group.program.roles.with_name(RoleConstants::ADMIN_NAME)
    group.stubs(:can_manage_mm_engagement_surveys?).with(admin_role).returns(false)
    assert_equal "-", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_scraps_disabled
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.stubs(:scraps_enabled?).returns(false)
    group_view = programs(:albers).group_view

    default_column = GroupViewColumn.where(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::MESSAGES_ACTIVITY).first

    assert_equal "-", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_posts_disabled
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.stubs(:forum_enabled?).returns(false)
    group_view = programs(:albers).group_view
    student_role_id = group.program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::POSTS_ACTIVITY, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE, role_id: student_role_id)
    assert_equal "-", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_survey_responses_disabled
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    admin_role = program.roles.with_name(RoleConstants::ADMIN_NAME)
    group.stubs(:can_manage_mm_engagement_surveys?).with(admin_role).returns(false)
    group_view = programs(:albers).group_view
    student_role_id = group.program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::SURVEY_RESPONSES, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE, role_id: student_role_id)
    assert_equal "-", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_goal_progress_for_no_goals
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::GOALS_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "No Goals Yet.", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_task_overdue_status
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view
    create_mentoring_model_task(group_id: group.id, required: true, due_date: Time.new(2002))
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::TASKS_OVERDUE_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "1", get_default_answer(group, default_column, true)
    assert_equal "1", get_default_answer(group, default_column, false)
  end

  def test_get_default_answer_for_task_completed_status
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view
    create_mentoring_model_task(group_id: group.id, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(group_id: group.id, status: MentoringModel::Task::Status::DONE)
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::TASKS_COMPLETED_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "2", get_default_answer(group, default_column, true)
    assert_equal "2", get_default_answer(group, default_column, false)
  end

  def test_get_default_answer_for_task_pending_status
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view
    create_mentoring_model_task(group_id: group.id, status: MentoringModel::Task::Status::TODO)
    create_mentoring_model_task(group_id: group.id, status: MentoringModel::Task::Status::TODO)
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::TASKS_PENDING_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "2", get_default_answer(group, default_column, true)
    assert_equal "2", get_default_answer(group, default_column, false)
  end

  def test_get_default_answer_for_milestone_overdue_status
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view

    milestone = create_mentoring_model_milestone(group_id: group.id)
    t1 = create_mentoring_model_task(milestone_id: milestone.id, title: "Carrie", group_id: group.id)
    t2 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", group_id: group.id)
    t3 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", required: true, status: MentoringModel::Task::Status::TODO, due_date: Date.today - 10.days, group_id: group.id)
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::MILESTONES_OVERDUE_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "1", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_milestone_pending_status
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view

    milestone = create_mentoring_model_milestone(group_id: group.id)
    task = create_mentoring_model_task(milestone_id: milestone.id, required: true, due_date: Date.today + 20.days, group_id: group.id, status: MentoringModel::Task::Status::TODO)
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::MILESTONES_PENDING_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "1", get_default_answer(group, default_column, false)
    assert_equal "1", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_milestone_completed_status
    program = programs(:albers)
    group = groups(:group_2)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view

    milestone = create_mentoring_model_milestone(group_id: group.id)
    t1 = create_mentoring_model_task(milestone_id: milestone.id, title: "Carrie", group_id: group.id)
    t2 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", group_id: group.id)
    t3 = create_mentoring_model_task(milestone_id: milestone.id, title: "Claire Danes", required: true, status: MentoringModel::Task::Status::DONE, due_date: Date.today - 10.days, group_id: group.id)
    default_column = GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::MILESTONES_COMPLETED_STATUS_V2, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    assert_equal "1", get_default_answer(group, default_column, true)
  end

  def test_get_default_answer_for_mentor_mentee_name
    group = groups(:mygroup)
    mentor_role_id = group.program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role_id = group.program.roles.find_by(name: RoleConstants::STUDENT_NAME)

    mentor_column = group.program.group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::MEMBERS, ref_obj_type: GroupViewColumn::ColumnType::NONE, role_id: mentor_role_id).first
    mentee_column = group.program.group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::MEMBERS, ref_obj_type: GroupViewColumn::ColumnType::NONE, role_id: student_role_id).first

    assert_match "Good unique name", get_default_answer(group, mentor_column, false)
    assert_match "Good unique name", get_default_answer(group, mentor_column, true)
    group.membership_of(group.mentors.first).update_attributes!(owner: true)
    assert_match "Good unique name (Owner)", get_default_answer(group, mentor_column, false)
    assert_match "Good unique name (Owner)", get_default_answer(group, mentor_column, true)

    assert_match "mkr_student madankumarrajan", get_default_answer(group, mentee_column, true)
    assert_match "mkr_student madankumarrajan", get_default_answer(group, mentee_column, false)
    group.membership_of(group.students.first).update_attributes!(owner: true)
    assert_match "mkr_student madankumarrajan (Owner)", get_default_answer(group, mentee_column, true)
    assert_match "mkr_student madankumarrajan (Owner)", get_default_answer(group, mentee_column, false)
  end

  def test_get_default_answer_proposed_by
    p = programs(:pbe)
    group_view = p.group_view
    GroupViewColumn.create!(:group_view => group_view, :column_key => GroupViewColumn::Columns::Key::PROPOSED_BY, :position => 1, :ref_obj_type => GroupViewColumn::ColumnType::NONE)
    mentor = users(:f_mentor_pbe)
    student = users(:f_student_pbe)
    admin = users(:f_admin_pbe)
    group = create_group(:students => [student], :mentor => mentor, :program => p, :status => 5, :created_by => admin)
    p.roles.find_by(name: RoleConstants::STUDENT_NAME).add_permission(RolePermission::PROPOSE_GROUPS)

    proposed_by_index_tab_5 = p.group_view.get_group_view_columns(5).collect(&:column_key).index("proposed_by")
    proposed_by_column_tab_5 = p.group_view.get_group_view_columns(5)[proposed_by_index_tab_5]
    proposed_by_text = get_default_answer(group, proposed_by_column_tab_5, false)
    assert_match "members\/#{admin.member.id}", proposed_by_text
    assert_no_match /Freakin Admin (Admin)/, proposed_by_text
    assert_match admin.name(name_only: true), proposed_by_text

    proposed_by_text = get_default_answer(group, proposed_by_column_tab_5, true)
    assert_no_match /members\/#{admin.member.id}/, proposed_by_text
    assert_no_match /Freakin Admin (Admin)/, proposed_by_text
    assert_match admin.name(name_only: true), proposed_by_text
  end

  def test_get_default_answer_closed_by
    group = groups(:group_4)
    group_view = group.program.group_view
    column = group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::CLOSED_BY).first
    assert_equal "Freakin Admin", get_default_answer(group, column, false)

    group.stubs(:closed_by).returns(nil)
    assert_equal "Administrator", get_default_answer(group, column, true)

    group.update_attribute(:termination_mode, Group::TerminationMode::EXPIRY)
    assert_equal "Auto closed", get_default_answer(group, column, false)
  end

  def test_group_view_sortable_actions
    group_view = programs(:pbe).group_view
    column = group_view.group_view_columns.first

    assert column.is_sortable?
    assert_match /sort_asc/, group_view_sortable_actions([column], column.column_key, "asc")
    assert_match /sort_both/, group_view_sortable_actions([column], "invalid", "asc")

    column.stubs(:is_sortable?).returns(false)
    assert_no_match(/sort/, group_view_sortable_actions([column], column.column_key, "asc"))
    assert_no_match(/sort/, group_view_sortable_actions([column], "invalid", "asc"))

    column = group_view.group_view_columns.last
    column.column_key = GroupViewColumn::Columns::Key::TOTAL_SLOTS
    column.role_id = group_view.program.roles.where(name: RoleConstants::MENTOR_NAME).first.id
    ret = group_view_sortable_actions([column], column.sorting_key, "asc")
    assert_match /membership_setting_total_slots.mentor/, ret
    assert_match /Number of slots \(Mentor\)/, ret

    column.column_key = GroupViewColumn::Columns::Key::MEMBERS
    ret = group_view_sortable_actions([column], column.sorting_key, "asc")
    assert_match /mentors.name_only.sort/, ret
    assert_match /Mentor/, ret

    column.role_id = group_view.program.roles.where(name: RoleConstants::TEACHER_NAME).first.id
    ret = group_view_sortable_actions([column], column.sorting_key, "desc")
    assert_match /role_users_full_name.teacher_name/, ret
    assert_match /Teacher/, ret
  end

  def test_get_default_answer_slot_columns
    program = programs(:pbe)
    group = groups(:group_pbe_0)
    group_view = program.group_view
    mentor_role_id = program.roles.where(name: RoleConstants::MENTOR_NAME).first.id
    student_role_id = program.roles.where(name: RoleConstants::STUDENT_NAME).first.id
    group.membership_settings.create!(role_id: mentor_role_id, max_limit: 15)

    assert_equal 15, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::TOTAL_SLOTS, role_id: mentor_role_id).first, false)
    assert_nil get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::TOTAL_SLOTS, role_id: student_role_id).first, false)
    assert_equal 1, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_TAKEN, role_id: mentor_role_id).first, false)
    assert_equal 2, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_TAKEN, role_id: student_role_id).first, false)
    assert_equal 14, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_REMAINING, role_id: mentor_role_id).first, false)
    assert_nil get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_REMAINING, role_id: student_role_id).first, false)
  end

  def test_get_default_answer_slot_columns_with_slot_details_hash
    program = programs(:pbe)
    group = groups(:group_pbe_0)
    group_view = program.group_view
    mentor_role_id = program.roles.where(name: RoleConstants::MENTOR_NAME).first.id
    student_role_id = program.roles.where(name: RoleConstants::STUDENT_NAME).first.id
    group.membership_settings.create!(role_id: mentor_role_id, max_limit: 15)
    groups_role_wise_slot_details = Group.get_rolewise_slots_details([group.id], true, true)

    assert_equal 15, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::TOTAL_SLOTS, role_id: mentor_role_id).first, false, slot_details: groups_role_wise_slot_details[group.id])
    assert_nil get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::TOTAL_SLOTS, role_id: student_role_id).first, false, slot_details: groups_role_wise_slot_details[group.id])
    assert_equal 1, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_TAKEN, role_id: mentor_role_id).first, false, slot_details: groups_role_wise_slot_details[group.id])
    assert_equal 2, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_TAKEN, role_id: student_role_id).first, false, slot_details: groups_role_wise_slot_details[group.id])
    assert_equal 14, get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_REMAINING, role_id: mentor_role_id).first, false, slot_details: groups_role_wise_slot_details[group.id])
    assert_nil get_default_answer(group, group_view.group_view_columns.where(column_key: GroupViewColumn::Columns::Key::SLOTS_REMAINING, role_id: student_role_id).first, false, slot_details: groups_role_wise_slot_details[group.id])
  end

  private

  def current_user
    @current_user || User.first
  end

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Mentee"
  end
end