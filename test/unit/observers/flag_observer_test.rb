require_relative './../../test_helper.rb'

class FlagObserverTest < ActiveSupport::TestCase

  def test_after_create
    Flag.expects(:send_content_flagged_admin_notification)
    create_flag(content: articles(:economy))
  end
end

