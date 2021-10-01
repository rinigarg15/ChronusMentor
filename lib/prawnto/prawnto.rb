require 'action_controller'
require 'action_view'

# Commenting the following line for Chronus Mentor due to dependency issue.
# require 'prawn'
begin 
  require "prawn/layout" # give people what they probably want
rescue LoadError
end

require 'action_controller'
require 'action_view'

require 'template_handler/compile_support'

require 'template_handlers/base'
#require 'prawnto/template_handlers/raw'

# for now applying to all Controllers
# however, could reduce footprint by letting user mixin (i.e. include) only into controllers that need it
# but does it really matter performance wise to include in a controller that doesn't need it?  doubtful-- depends how much of a hit the before_filter is i guess.. 
#

class ActionController::Base
  class_attribute :ca_prawn, :ca_prawnto
  include Prawnto::ActionController
end

class ActionView::Base
  include Prawnto::ActionView
end



