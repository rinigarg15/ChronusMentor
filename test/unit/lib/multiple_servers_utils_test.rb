require_relative './../../test_helper.rb'

class MultipleServersUtilsTest < ActiveSupport::TestCase
  def test_detect_multiple_primary_app_servers_running
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("staging"))
    MultipleServersUtils.stubs(:multiple_servers_running?).returns(true)
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      MultipleServersUtils.detect_multiple_servers_running
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal ["monitor@chronus.com"], email.from
    assert_equal ["monitor+sendmail@chronus.com"], email.to
    assert_match "Multiple Primary/Collapse servers are running in staging. Please stop the other server for staging <EOM>", email.subject
    assert email.body.empty?
  end

  def test_multiple_servers_running
    Object.const_set("AWS_ES_OPTIONS", { es_region: "us-east-1" } )
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("staging"))
    y = mock()
    y.stubs(:instances).returns(nil)
    Aws::EC2::Resource.stubs(:new).returns(y)
    assert_equal false, MultipleServersUtils.multiple_servers_running?
  end

  def test_get_servers_running
    assert_equal 1, MultipleServersUtils.get_servers_count(["primary_app", "secondary_app", "collapsed"])
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("staging"))
    Object.const_set("AWS_ES_OPTIONS", { es_region: "us-east-1" } )
    stubbed_ec2 = Aws::EC2::Resource.new(stub_responses: true)
    Aws::EC2::Resource.stubs(:new).returns(stubbed_ec2)
    Aws::EC2::Resource.any_instance.expects(:instances).with({filters: [{name: 'tag:Environment', values: [Rails.env]}, {name: 'tag:ServerRole', values: ["primary_app", "secondary_app", "collapsed"]}, {name: "instance-state-name" , values: ["running"]}]}).returns(["primary_instance", "secondary_instance"])
    assert_equal 2, MultipleServersUtils.get_servers_count(["primary_app", "secondary_app", "collapsed"])
  end
  
end