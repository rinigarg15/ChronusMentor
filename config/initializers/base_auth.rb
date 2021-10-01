ActionController::Base.send(:include, Authorization)
ActionController::Base.send(:helper_method, [:allow, :deny])