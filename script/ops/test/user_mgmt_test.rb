require 'rubygems'
require 'test/unit'
require 'mocha'
require_relative './../user_mgmt.rb'


class UserMgmtTest < Test::Unit::TestCase

  def setup
    super
    # Stubbing execute_cmd, logging functions
    UserMgmt.any_instance.stubs(:execute_cmd).raises(RuntimeError, "Mock the instance execute_cmd!")
    UserMgmt.stubs(:execute_cmd).raises(RuntimeError, "Mock the class execute_cmd!")

    UserMgmt.any_instance.stubs(:error_log).returns(true)
    UserMgmt.any_instance.stubs(:success_log).returns(true)
    UserMgmt.any_instance.stubs(:info_log).returns(true)

    UserMgmt.stubs(:error_log).returns(true)
    UserMgmt.stubs(:success_log).returns(true)
    UserMgmt.stubs(:info_log).returns(true)
  end

  def test_push_ssh_key_to_users_creds_dir
    mock_aws_config
    mock_aws_iam
    s3_obj = mock_aws_s3
    keypair = mock_keypair

    bucket = mock('s3-bucket')
    objects_collection = mock('objects-collection')

    s3_obj.expects(:buckets)
      .returns({
        "chronus-mentor-ks-dev" => bucket
      })

    bucket.expects(:objects).returns(objects_collection)

    objects_collection.expects(:create)
      .with("dev_auth/dev_test/test-ssh-key",'privkey',:server_side_encryption => :aes256)
      .returns(true)

    cm_obj = UserMgmt.new("dev_test","access_key","secret_key")
    cm_obj.send(:push_ssh_key_to_users_creds_dir, keypair,"test-ssh-key",:server_side_encryption => :aes256)
  end

  def test_delete_s3_obj_should_delete_a_given_s3_obj_from_creds_bucket
    mock_aws_config
    mock_aws_iam
    s3_mock = mock_aws_s3
    cm_obj = UserMgmt.new("dev_test","access_key","secret_key")

    bucket_mock = mock('s3-bucket')
    s3_mock.expects(:buckets)
      .returns({
        "chronus-mentor-ks-dev" => bucket_mock
      })

    s3_obj_mock = mock('s3-obj')
    bucket_mock.expects(:objects)
      .returns({
        "s3-obj" => s3_obj_mock
      })

    s3_obj_mock.expects(:delete).returns
    cm_obj.send(:delete_s3_obj,"s3-obj")
  end

  def test_remove_s3_obj_for_user_should_delete_s3_obj_from_users_creds_dir
    mock_aws_config
    mock_aws_iam
    mock_aws_s3
    cm_obj = UserMgmt.new("dev_test","access_key","secret_key")

    cm_obj.expects(:delete_s3_obj)
      .with("dev_auth/dev_test/s3-obj")
      .returns

    cm_obj.send(:remove_s3_obj_for_user, "s3-obj")

  end

  private

  def mock_keypair
    {
      "private_key" => "privkey", 
      "public_key" => "pubkey",
      "keypair_name" => "keypair"
    } 
  end

  def mock_aws_config
    AWS.expects(:config).with({
      :access_key_id => "access_key", 
      :secret_access_key => "secret_key",
      :region => "us-east-1" 
    }).returns(true)
  end

  def mock_aws_iam
    iam_mock = mock('iam')
    iam_mock.expects(:groups).returns(Hash.new)
    iam_mock.expects(:users).returns(Hash.new)
    AWS::IAM.expects(:new).returns(iam_mock)
  end

  def mock_aws_s3
    s3_mock = mock('s3')
    AWS::S3.expects(:new).returns(s3_mock)
    return s3_mock
  end
end
