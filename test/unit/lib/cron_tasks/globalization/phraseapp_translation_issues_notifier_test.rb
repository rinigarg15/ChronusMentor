require_relative './../../../../test_helper'

class CronTasks::Globalization::PhraseappTranslationIssuesNotifierTest < ActiveSupport::TestCase

  def test_perform
    Globalization::PhraseappUtils.expects(:notify_corrupted_translations).once
    CronTasks::Globalization::PhraseappTranslationIssuesNotifier.new.perform
  end
end