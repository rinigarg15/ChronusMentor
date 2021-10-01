# -*- encoding: utf-8 -*-
require_relative './../../../../test_helper'

class AutodeskPreprocessorTest < ActiveSupport::TestCase

  def test_pre_process
    ChronusSftpFeed::Preprocessor::AutodeskPreprocessor.expects(:decrypt_feed_data).with("test_file.pgp", ChronusSftpFeed::Preprocessor::AutodeskPreprocessor::PUBLIC_KEY_FILE, ChronusSftpFeed::Preprocessor::AutodeskPreprocessor::PRIVATE_KEY_FILE)
    ChronusSftpFeed::Preprocessor::AutodeskPreprocessor.pre_process("test_file.pgp", is_encrypted: true)
  end
end