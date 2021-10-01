REDIS_CONFIG ||= YAML::load(ERB.new(File.read("#{Rails.root}/config/redis.yml")).result)[Rails.env].symbolize_keys

redis = Redis.new(:host => REDIS_CONFIG[:host], :port => REDIS_CONFIG[:port], :password => REDIS_CONFIG[:password], :username => REDIS_CONFIG[:user])
Split.redis = Redis::Namespace.new("split:#{REDIS_CONFIG[:namespace_suffix]}", redis: redis)

Split.configure do |config|
  config.db_failover = true
  config.db_failover_on_db_error = proc{|error| Airbrake.notify(error)}
  config.enabled = AB_TESTING_ENABLED
  config.allow_multiple_experiments = true
  config.persistence = Split::Persistence::RedisAdapter.with_config(:lookup_by => proc { |context| context.current_member_or_cookie })
  config.experiments = ProgramAbTest.experiment_configs
end

Split::Dashboard.use Rack::Auth::Basic do |username, password|
  username == SUPERADMIN_EMAIL && password == APP_CONFIG[:super_console_pass_phrase]
end