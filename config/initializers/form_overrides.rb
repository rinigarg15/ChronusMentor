require "action_view/helpers/form_helper.rb"
require "action_view/helpers/form_tag_helper.rb"

module ActionViewHelpersFormHelperBrowserJsCheck
  def form_for(record, options = {}, &block)
    super.gsub("</form>", "<noscript><input type='hidden' value='true' name='javascript_disabled' /></noscript></form>").html_safe
  end
end

module ActionViewHelpersFormTagHelperBrowserJsCheck
  def form_tag(url_for_options = {}, options = {}, &block)
    super.gsub("</form>", "<noscript><input type='hidden' value='true' name='javascript_disabled' /></noscript></form>").html_safe
  end
end

ActionView::Helpers::FormHelper.prepend(ActionViewHelpersFormHelperBrowserJsCheck)
ActionView::Helpers::FormTagHelper.prepend(ActionViewHelpersFormTagHelperBrowserJsCheck)