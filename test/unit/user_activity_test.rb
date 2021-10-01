require_relative './../test_helper.rb'

class UserActivityTest < ActiveSupport::TestCase
  def test_associations
    ua = UserActivity.new
    assert_nil ua.user
    assert_nil ua.member
    assert_nil ua.organization
    assert_nil ua.program

    ua = UserActivity.new(user: users(:f_admin), member: members(:f_admin), program: programs(:albers), organization: programs(:org_primary))
    assert_equal ua.user, users(:f_admin)
    assert_equal ua.member, members(:f_admin)
    assert_equal ua.organization, programs(:org_primary)
    assert_equal ua.program, programs(:albers)
  end

  def test_export_to_csv
    file_path = "#{Rails.root}/test/fixtures/files/user_activity_export.csv"
    UserActivity.export_to_csv(file_path)
    assert_equal 1, CSV.read(file_path).count

    time = "2017-06-13 13:01:48 UTC"
    activity1 = {activity: "something",  happened_at: time, member_id: 1, user_id: 1, organization_id: 1, program_id: 1, roles: "roles", current_connection_status: "Ongoing", past_connection_status: "Onetime", join_date: time, mentor_request_style: 0, program_url: "someurl", account_name: "some name", browser_name: "browser", platform_name: "platform", device_name: "device", context_place: "", context_object: "", created_at: time, updated_at: time}
    activity2 = {activity: "something else",  happened_at: time, member_id: 1, user_id: nil, organization_id: 1, program_id: nil, roles: "", current_connection_status: "", past_connection_status: "", join_date: time, mentor_request_style: nil, program_url: "", account_name: "some name", browser_name: "browser", platform_name: "platform", device_name: "device", context_place: "place", context_object: "object", created_at: time, updated_at: time}
    UserActivity.create!(activity1)
    UserActivity.create!(activity2)

    UserActivity.export_to_csv(file_path)
    assert_equal 3, CSV.read(file_path).count
    expected_arrays = [UserActivity.column_names, [UserActivity.first.id.to_s] + activity1.values.map(&:to_s), [UserActivity.last.id.to_s] + activity2.values.map{|v| v.nil? ? nil : v.to_s}]
    CSV.foreach(file_path) do |row|
      assert_equal expected_arrays.shift, row
    end

    UserActivity.export_to_csv(file_path, "id", "activity")
    assert_equal 3, CSV.read(file_path).count
    expected_arrays = [["id", "activity"], [UserActivity.first.id.to_s, "something"], [UserActivity.last.id.to_s, "something else"]]
    CSV.foreach(file_path) do |row|
      assert_equal expected_arrays.shift, row
    end
  end
end