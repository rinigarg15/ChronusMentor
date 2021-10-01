require_relative './../../../../test_helper'

class CronTasks::Globalization::UntranslatedStringsNotifierTest < ActiveSupport::TestCase

  def test_perform
    Globalization::PhraseappUtils.expects(:notify_untranslated_strings).once
    CronTasks::Globalization::UntranslatedStringsNotifier.new.perform
  end
end