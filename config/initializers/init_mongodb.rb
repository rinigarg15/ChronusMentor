#Mongo Logger Level
Mongo::Logger.logger.level = Logger::WARN

if (ENV['TDDIUM'].to_i == 1) && Rails.env.test?
  Mongoid.load!("config/solano_mongo.yml", :test)
end

#Not raise mongo document not found error
Mongoid.raise_not_found_error = false

# Create indexes if not present
Matching::Persistence::Score.create_indexes
Matching::Persistence::Setting.create_indexes

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    Mongoid::Clients.default.reconnect if forked
  end
end