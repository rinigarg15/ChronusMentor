require 'open-uri'
require 'net/http'
require 'uri'
require 'json'
require_relative './deployment_constants'
require_relative './deployment_module_helper'
require_relative './deployment_helper'

class ServiceMaintenance
  include DeploymentConstants
  include DeploymentModuleHelper

  def start_maintenance(service_id)
    puts "scheduling pagerduty maintenance"
    uri = URI.parse("https://api.pagerduty.com/maintenance_windows")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Accept"] = "application/vnd.pagerduty+json;version=2"
    request["From"] = PAGERDUTY_REQUEST_ID
    request["Authorization"] = "Token token=#{ENV["PAGERDUTY_API_KEY"]}"
    request.body = JSON.dump({
      "maintenance_window" => {
        "type" => "maintenance_window",
        "start_time" => "#{Time.now}",
        "end_time" => "#{Time.now+PAGERDUTY_MAINTENANCE_TIME}",
        "description" => "Deployment maintenance",
        "services" => [
          {
            "id" => service_id,
            "type" => "service_reference"
          }
        ]
      }
    })

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
  end

  def stop_maintenance(maintenance_id)
    puts "Stopping pagerduty maintenance  Maintenance Id: #{maintenance_id}"
    uri = URI.parse("https://api.pagerduty.com/maintenance_windows/#{maintenance_id}")
    request = Net::HTTP::Delete.new(uri)
    request["Accept"] = "application/vnd.pagerduty+json;version=2"
    request["Authorization"] = "Token token=#{ENV["PAGERDUTY_API_KEY"]}"

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = retry_when_exception("Enable to stop Maintenance for PAGERDUTY. Check the apollo.pagerduty.com/maintenance_windows manually"){
      Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    }
  end

  def pagerduty_maintenance(pagerduty_maintenance_services = PAGERDUTY_MAINTENANCE)
    maintenance_id_arr = []
    pagerduty_maintenance_services.each do |key, value|
      puts "Pagerduty: #{key} maintenance for #{PAGERDUTY_MAINTENANCE_TIME} seconds"
      retry_when_exception("Enable to create Maintenance for PAGERDUTY Service: #{key}. Check the apollo.pagerduty.com/maintenance_windows manually"){
        response = start_maintenance(value)
        maintenance_id_arr.push(JSON.parse(response.body)["maintenance_window"]["id"])
      }
    end
    maintenance_id_arr
  end
end