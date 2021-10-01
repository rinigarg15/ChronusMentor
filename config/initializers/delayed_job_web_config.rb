DelayedJobWeb.use Rack::Auth::Basic do |username, password|
  username == "chronusmentor" && password == APP_CONFIG[:super_console_pass_phrase]
end
DelayedJobWeb.set(:allow_requeue_pending, false)