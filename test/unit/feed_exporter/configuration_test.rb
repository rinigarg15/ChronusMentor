require_relative './../../test_helper.rb'

class FeedExporter::ConfigurationTest < ActiveSupport::TestCase

  def setup
    super
    @organization = programs(:org_primary)
    @feed_exporter = FeedExporter.create!(program_id: @organization.id, sftp_account_name: "test")
  end

  def test_validations
    config = FeedExporter::Configuration.new
    assert_false config.valid?
    expected_hash = {feed_exporter: ["can't be blank"], configuration_options: ["can't be blank"]}
    assert_equal expected_hash, config.errors.messages

    config.feed_exporter = @feed_exporter
    config.configuration_options = { headers: [], profile_question_texts: [] }
    assert config.valid?
  end

  def test_load_configuration
    mem_config = FeedExporter::MemberConfiguration.new(feed_exporter: @feed_exporter)
    mem_config.set_config_options!({headers: ["member_id", "first_name", "last_name", "email"], profile_question_texts: ["Gender"]})

    group_config = FeedExporter::ConnectionConfiguration.new(feed_exporter: @feed_exporter)
    group_config.set_config_options!({headers: ["group_id", "group_name", "program_root", "program_name"], profile_question_texts: ["Gender"]})

    mem_config = @feed_exporter.feed_exporter_configurations.find_by(type: "FeedExporter::MemberConfiguration")
    assert_equal ["member_id", "first_name", "last_name", "email"], mem_config.headers
    assert_equal ["Gender"], mem_config.profile_question_texts

    conn_config = @feed_exporter.feed_exporter_configurations.find_by(type: "FeedExporter::ConnectionConfiguration")
    assert_equal ["group_id", "group_name", "program_root", "program_name"], conn_config.headers
    assert_equal ["Gender"], conn_config.profile_question_texts
  end

  def test_get_header_text
    mem_config = FeedExporter::MemberConfiguration.new(feed_exporter: @feed_exporter)
    mem_config.set_config_options!({headers: ["member_id", "first_name", "last_name", "email"], profile_question_texts: ["Gender"]})

    group_config = FeedExporter::ConnectionConfiguration.new(feed_exporter: @feed_exporter)
    group_config.set_config_options!({headers: ["group_id", "group_name", "program_root", "program_name"], profile_question_texts: ["Gender"]})
    group_config.save!

    assert_equal "Program", mem_config.send(:get_header_text, "program")
    assert_equal "Member Status", mem_config.send(:get_header_text, "member_status")
    assert_equal "Member Id", mem_config.send(:get_header_text, "member_id")

    assert_equal "Mentoring Connection Id", group_config.send(:get_header_text, "group_id")
    assert_equal "Status", group_config.send(:get_header_text, "group_status")
  end

  def test_get_value
    mem_config = FeedExporter::MemberConfiguration.new(feed_exporter: @feed_exporter)
    mem_config.set_config_options!({headers: ["member_id", "first_name", "last_name", "email"], profile_question_texts: ["Gender"]})
    mem_config.save!

    mem_config.member = members(:f_mentor)
    assert_equal members(:f_mentor).id, mem_config.send(:get_value, "member_id")
    assert_equal members(:f_mentor).first_name, mem_config.send(:get_value, "first_name")
  end

  def test_get_groups_data
    group = groups(:mygroup)
    program = group.program

    group_config = FeedExporter::ConnectionConfiguration.new(feed_exporter: @feed_exporter)
    group_config.set_config_options!({headers: ["group_id", "group_name", "program_root", "program_name", "role_names", "role_ids", "group_status", "group_notes", "active_since", "last_activity_at", "expires_on"], profile_question_texts: ["Gender"]})

    @feed_exporter.organization.stubs(:programs).returns(Program.where(id: program.id))
    Program.any_instance.stubs(:groups).returns(Group.where(id: group.id))
    group_config.load_configurations
    groups_data = group_config.get_data
    fields = groups_data.first.keys
    data = groups_data.first

    assert_equal_unordered ["Mentoring Connection Id", "Mentoring Connection", "Program", "Program Name", "Mentor", "Mentor Id", "Mentor - Gender", "Student", "Student Id", "Student - Gender", "Status", "Notes", "Active since", "Last activity", "Expires on"], fields
    assert_equal 1, groups_data.count
    assert_equal group.id, data["Mentoring Connection Id"]
    assert_equal group.name, data["Mentoring Connection"]
    assert_equal program.root, data["Program"]
    assert_equal members(:f_mentor).name, data["Mentor"]
    assert_equal "#{members(:f_mentor).id}", data["Mentor Id"]
    assert_equal "", data["Mentor - Gender"]
    assert_equal members(:mkr_student).name, data["Student"]
    assert_equal "#{members(:mkr_student).id}", data["Student Id"]
    assert_equal "Active", data["Status"]
    assert_equal "", data["Notes"]
    assert_equal DateTime.localize(group.published_at, format: :date_range), data["Active since"]
    assert_equal DateTime.localize(group.last_member_activity_at, format: :date_range), data["Last activity"]
    assert_equal DateTime.localize(group.expiry_time, format: :date_range), data["Expires on"]
  end


  def test_get_members_data
    member = members(:f_student)
    member.update_attributes!(last_suspended_at: Time.now)
    user = member.users.first
    tag_array = ["Tag name 1", "Tag name 2", "Tag name 3"]
    user.update_attributes!(last_deactivated_at: Time.now)
    user_1 =member.users.last
    tag_array.each do |tag|
      user_1.tags.create!(name: tag)
    end
    mentoring_model_array = [MentoringModel.first, MentoringModel.last]
    groups = member.users.collect(&:groups).flatten.compact
    g1 = groups.first
    g2 = groups.last
    g1.mentoring_model = mentoring_model_array[0]
    g1.save!
    g2.mentoring_model = mentoring_model_array[1]
    g2.save!
    time_now = Time.now.utc
    g1.update_attributes!(published_at: time_now)

    organization = member.organization
    role_1 = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME)

    mem_config = FeedExporter::MemberConfiguration.new(feed_exporter: @feed_exporter)
    mem_config.set_config_options!({headers: ["member_id", "first_name", "last_name", "email", "member_status", "joined_on", "active_connections_count", "last_suspended_on", "program", "role_name", "role_id", "user_status", "last_deactivated_on", "tags", "recent_connection_started_on", "connection_plan_template_names"], profile_question_texts: ["Gender"]})

    @feed_exporter.organization.stubs(:members).returns(Member.where(id: member.id))
    mem_config.load_configurations

    members_data = mem_config.get_data
    fields = members_data.first.keys
    data = members_data.first

    assert_equal 3, members_data.count
    assert_equal ["Member Id", "First Name", "Last Name", "Email", "Member Status", "Joined on Date", "Number of connections (Current)", "Last Suspended On", "Program", "Role", "Role Id", "Status", "Last Deactivated On", "Tags", "Started on ( recent mentoring connection )", "Mentoring Connection Plan Templates", "Gender"], fields

    assert_equal member.id, data["Member Id"]
    assert_equal member.first_name, data["First Name"]
    assert_equal member.last_name, data["Last Name"]
    assert_equal member.email, data["Email"]
    assert_equal "Active", data["Member Status"]
    assert_equal programs(:albers).name, data["Program"]
    assert_equal "Student", data["Role"]
    assert_equal "#{role_1.id}", data["Role Id"]
    assert_equal "Active", data["Status"]
    assert_equal DateTime.localize(member.created_at, format: :full_display_no_time), data["Joined on Date"]
    assert_equal 2, data["Number of connections (Current)"]
    assert_equal DateTime.localize(member.last_suspended_at, format: :full_display_no_time), data["Last Suspended On"]
    assert_equal DateTime.localize(user.last_deactivated_at, format: :full_display_no_time), data["Last Deactivated On"]

    members_data[1..-1].each_with_index do |member_data, index|
      assert_equal data.except("Program", "Role Id", "Role", "Last Deactivated On", "Started on ( recent mentoring connection )", "Mentoring Connection Plan Templates","Tags"), member_data.except("Program", "Role Id", "Role", "Last Deactivated On", "Started on ( recent mentoring connection )", "Mentoring Connection Plan Templates","Tags")
      if index == 0
        assert_equal programs(:nwen).name, member_data["Program"]
        assert_equal "Mentor", member_data["Role"]
        assert_nil member_data["Tags"]
        assert_equal "Albers Mentor Program Template", member_data["Mentoring Connection Plan Templates"]
        assert_equal DateTime.localize(time_now, format: :date_range), member_data["Started on ( recent mentoring connection )"]
      else
        assert_equal programs(:pbe).name, member_data["Program"]
        assert_equal "Student", member_data["Role"]
        assert_equal_unordered tag_array, member_data["Tags"].split(",")
        assert_equal_unordered ["Project Based Engagement Template" ,"NCH Mentoring Program Template"], member_data["Mentoring Connection Plan Templates"].split(",")
      end
    end
  end


end