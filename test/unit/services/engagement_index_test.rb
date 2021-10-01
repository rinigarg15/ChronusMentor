require_relative './../../test_helper.rb'

class EngagementIndexTest < ActiveSupport::TestCase

  def test_initialize
    ei = EngagementIndex.new(members(:f_admin), programs(:org_primary), users(:f_admin), programs(:albers), new_browser, false)
  end

  def test_save_activity
    ei = EngagementIndex.new(members(:f_admin), programs(:org_primary), users(:f_admin), programs(:albers), new_browser, false)
    ei.stubs(:to_be_ignored?).returns(true)
    assert_no_difference "UserActivity.count" do
      assert_false ei.save_activity!(EngagementIndex::Activity::LOGIN)
    end

    ei.stubs(:to_be_ignored?).returns(false)
    
    assert_difference "UserActivity.count", 1 do
      assert ei.save_activity!(EngagementIndex::Activity::LOGIN)
    end
    ua = UserActivity.last
    assert_equal members(:f_admin).id, ua.member_id
    assert_equal users(:f_admin).id, ua.user_id
    assert_equal programs(:org_primary).id, ua.organization_id
    assert_equal programs(:albers).id, ua.program_id
  end

  def test_get_data_hash
    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), users(:f_student), programs(:albers), new_browser, false)
    Timecop.freeze(Time.now) do
      expected_result = {
        happened_at: Time.now.utc,
        user_details: "user_details",
        program_details: "program_details",
        browser_details: "browser_details"
      }
      ei.stubs(:user_details).returns({user_details: "user_details"})
      ei.stubs(:program_details).returns({program_details: "program_details"})
      ei.stubs(:browser_details).returns({browser_details: "browser_details"})
      assert_equal expected_result, ei.send(:get_data_hash)
    end
  end

  def test_user_details
    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), users(:f_student), programs(:albers), new_browser, false)
    expected_result = {
      member_id: members(:f_student).id,
      user_id: users(:f_student).id,
      roles: "student",
      current_connection_status: users(:f_student).current_connection_status,
      past_connection_status: users(:f_student).past_connection_status,
      join_date: members(:f_student).terms_and_conditions_accepted
    }
    assert_equal expected_result, ei.send(:user_details)

    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), nil, nil, new_browser, false)
    expected_result = {
      member_id: members(:f_student).id,
      user_id: nil,
      roles: nil,
      current_connection_status: nil,
      past_connection_status: nil,
      join_date: members(:f_student).terms_and_conditions_accepted
    }
    assert_equal expected_result, ei.send(:user_details)
  end

  def test_program_details
    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), users(:f_student), programs(:albers), new_browser, false)
    expected_result = {
      organization_id: programs(:org_primary).id,
      program_id: programs(:albers).id,
      mentor_request_style: programs(:albers).mentor_request_style,
      program_url: programs(:albers).url,
      account_name: programs(:org_primary).account_name
    }
    assert_equal expected_result, ei.send(:program_details)

    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), nil, nil, new_browser, false)
    expected_result = {
      organization_id: programs(:org_primary).id,
      program_id: nil,
      mentor_request_style: nil,
      program_url: programs(:org_primary).url,
      account_name: programs(:org_primary).account_name
    }
    assert_equal expected_result, ei.send(:program_details)
  end

  def test_browser_details
    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), users(:f_student), programs(:albers), new_browser, false)
    expected_result = {
      browser_name: new_browser.name,
      platform_name: new_browser.platform.name,
      device_name: new_browser.device.name
    }
    assert_equal expected_result, ei.send(:browser_details)
  end

  def test_to_be_ignored
    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), users(:f_student), programs(:albers), new_browser, false)
    assert_false ei.send(:to_be_ignored?)
    ei = EngagementIndex.new(members(:f_student), programs(:org_primary), users(:f_student), programs(:albers), new_browser, true)
    assert ei.send(:to_be_ignored?)
    ei = EngagementIndex.new(members(:f_admin), programs(:org_primary), users(:f_admin), programs(:albers), new_browser, false)
    assert ei.send(:to_be_ignored?)
  end

  private

  def new_browser
    Browser.new("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome", accept_language: "en-us")
  end
end