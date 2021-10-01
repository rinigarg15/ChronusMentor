require_relative './../../../test_helper'

class BBNCAuthTest < ActiveSupport::TestCase

  def test_authenticate_true
    uid, ts, sig, pkey, options = test_data_correct
    res_hash = {:userid => uid, :ts =>  ts , :sig => sig}
    Digest::MD5.expects(:hexdigest).at_least(1).returns(sig)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, [res_hash])
    assert BBNCAuth.authenticate?(auth_obj, options)
    assert_equal uid, auth_obj.uid
  end

  # one without sig
  def test_authenticate_false
    uid, ts, sig, pkey, options = test_data_correct
    res_hash = {:userid => uid, :ts =>  ts}
    Digest::MD5.expects(:hexdigest).at_least(1).returns(sig)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, [res_hash])
    assert_false BBNCAuth.authenticate?(auth_obj, options)
  end

  # one with random sig
  def test_authenticate_wrong_sig
    uid, ts, sig, pkey, options = test_data_correct
    res_hash = {:userid => uid, :ts =>  ts , :sig => sig}
    Digest::MD5.expects(:hexdigest).at_least(1).returns(sig+"random")
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, [res_hash])
    assert_false BBNCAuth.authenticate?(auth_obj, options)
  end

  # one whose response is delayed
  def test_authenticate_delayed_false
    uid, ts, sig, pkey, options = test_data_delayed
    res_hash = {:userid => uid, :ts =>  ts , :sig => sig}
    Digest::MD5.expects(:hexdigest).never
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, [res_hash])
    assert_false BBNCAuth.authenticate?(auth_obj, options)
  end

  private

  def test_data_correct
    uid = "5"
    pkey = "9n68erf6gy09picxs43545yi0"
    ts   = Time.now.round(7).iso8601(7).to_s
    sig = Digest::MD5.hexdigest(uid+ts+pkey)
    options = {"url"=>"test_url", "redirect_url"=>"our_login_site", "private_key"=>pkey}
    [uid, ts, sig, pkey,options]
  end

  def test_data_delayed
    uid = "5"
    pkey = "9n68erf6gy09picxs43545yi0"
    ts   = (Time.now-305).round(7).iso8601(7)
    sig = Digest::MD5.hexdigest(uid+ts+pkey)
    options = {"url"=>"test_url", "redirect_url"=>"our_login_site", "private_key"=>pkey}
    [uid, ts, sig, pkey,options]
  end

end