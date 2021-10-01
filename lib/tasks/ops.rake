namespace :ops do
  task :update_mentoradmin_password => :environment do |t|
    require 'highline/import'
    password = ask("Enter the new MentorAdmin Password:") { |q| q.echo = false}
    password_confirmation = ask("Retype Password:") { |q| q.echo = false}

    abort "Password does not match the confirm password" unless password == password_confirmation
    begin
      ActiveRecord::Base.transaction do
        mentor_admins = Member.where(:email => SUPERADMIN_EMAIL)
        mentor_admins.each do |m|
          m.password = password
          m.password_confirmation = password
          m.save!
        end
      end
      puts "\nSuccessfully updated the mentor admin password".green
    rescue Exception => e
      puts "\nUpdating mentoradmin password failed #{e.message}".red
    end
  end
  def get_period(duration)
    current_time = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    start_time = (Time.now-duration).utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    "from=#{start_time}&to=#{current_time}"
  end

  def get_response_body(options)
    "#{options[:metric_names]}&#{get_period(options[:duration])}&summarize=true"
  end

  def send_request(options)
    uri = URI.parse(options[:url])
    request = Net::HTTP::Get.new(uri)
    request["X-Api-Key"] = options[:api_key]
    request.body = get_response_body(options) if options[:get_metric_data]
    req_options = {
      use_ssl: uri.scheme == "https",
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    return JSON.parse(response.body)
  end

  def write_app_metrics(options)
    options[:app_ids].each do |app_id|
      app_metrics = options[:apdex_response][app_id]["metric_data"]["metrics"].select{|s| s["name"] == options[:metric]}.first
      app_metric_values = app_metrics["timeslices"].first["values"] if app_metrics
      score = (options[:metric] == "HttpDispatcher" ? app_metric_values["requests_per_minute"] : app_metric_values["score"])
      options[:csv_file] << [ options[:env_app_id_mapping][app_id], options[:display_metric], Time.now.strftime("%d/%m/%Y"), score ]
    end
  end

  def write_server_metrics(options)
    options[:app_ids].each do |app_id|
      options[:server_ids][app_id].each do |server_id|
        server_response = send_request({:url => "https://api.newrelic.com/v2/servers/#{server_id}/metrics/data.json", :get_metric_data => true, :metric_names => "names[]=#{options[:metric]}", :duration => @duration, :api_key => options[:api_key]})
        server_value = (server_response["metric_data"]["metrics"].select{|s| s["name"] == options[:metric]}.first["timeslices"].first["values"]["average_value"])
        server_value = (server_value.to_f/1024/1024/1024).round(2) if options[:metric] == "System/Memory/Used/bytes"
        options[:csv_file] << ["#{options[:env_server_id_mapping][server_id]}(#{options[:env_app_id_mapping][app_id]})", options[:display_metric], Time.now.strftime("%d/%m/%Y"), server_value]
      end
    end
  end


  #For internal purposes. 
  #Pulls Apdex, Browser Apdex and RPM from application for 1 week and stores in CSV.
  #Pulls CPU and Memory from server for 1 week and stores in CSV.
  desc "Pull Metric data from newrelic"
  task :pull_metric_from_newrelic => :environment do
    #csv_file = []
    csv_file = CSV.open(File.expand_path("~/newrelic_metrics/newrelic_metrics_#{Time.now.strftime('%d_%m_%Y')}.txt"), "a")
    API_KEYS = ENV["NEWRELIC_API_KEYS"].split(",")
    @duration = 1.day
    API_KEYS.each do |api_key|
      get_all_apps = send_request({:url => "https://api.newrelic.com/v2/applications.json", :api_key => api_key})
      env_app_id_mapping = {}
      get_all_apps["applications"].each{|app| env_app_id_mapping[app["id"]] = app["name"] if app["health_status"] != "gray"}
      app_server_ids = {}
      get_all_apps["applications"].each{|app| app_server_ids[app["id"]] = app["links"]["servers"] if app["health_status"] != "gray"}
      apdex_response = {}
      app_server_ids.keys.each do |app_id|
        apdex_response[app_id] = send_request({:url => "https://api.newrelic.com/v2/applications/#{app_id}/metrics/data.json", :get_metric_data => true, :metric_names => "names[]=Apdex&names[]=EndUser/Apdex&names[]=HttpDispatcher", :duration => @duration, :api_key => api_key})
      end

      app_ids = apdex_response.keys
      #App Metrics
      csv_file << ["Environment", "Metric", "Period(from 7 days prior)", "Score"]

      write_app_metrics_options = {app_ids: app_ids, apdex_response: apdex_response, csv_file: csv_file, env_app_id_mapping: env_app_id_mapping}
      write_app_metrics(write_app_metrics_options.merge({metric: "Apdex", display_metric: "App Apdex"}))
      write_app_metrics(write_app_metrics_options.merge({metric: "EndUser/Apdex", display_metric: "Browser Apdex"}))
      write_app_metrics(write_app_metrics_options.merge({metric: "HttpDispatcher", display_metric: "Average RPM"}))

      env_server_id_mapping = {}
      server_ids = {}
      app_server_ids.keys.each do |app_id|
        server_response = send_request({:url => "https://api.newrelic.com/v2/applications/#{app_id}/hosts.json", :api_key => api_key})
        server_ids[app_id] = server_response["application_hosts"].map{|s| s["links"]["server"]}
        server_response["application_hosts"].each{|a| env_server_id_mapping[a["links"]["server"]]=a["host"]}
      end
      #Server Metrics
      csv_file << ["Server(Environment)", "Metric", "Period(from 7 days prior)", "Value"]

      write_server_metrics_options = {app_ids: app_ids, server_ids: server_ids, csv_file: csv_file, env_app_id_mapping: env_app_id_mapping, env_server_id_mapping: env_server_id_mapping, api_key: api_key}
      write_server_metrics(write_server_metrics_options.merge({metric: "System/CPU/User/percent", display_metric: "Average CPU"}))
      write_server_metrics(write_server_metrics_options.merge({metric: "System/Memory/Used/bytes", display_metric: "Average Memory"}))
    end
    csv_file.close
  end
end
