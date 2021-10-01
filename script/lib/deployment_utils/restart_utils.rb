require File.dirname(__FILE__) + '/aws_utils_v2'

module DeploymentUtils
  module RestartUtils
    class Manager

      def initialize(environment, options = {})
        AWSUtilsV2.initialize_aws_v2(options[:access_key_id], options[:secret_access_key], options[:region]) if options[:access_key_id] && options[:secret_access_key] && options[:region]
        @environment = environment
        @role_ips = options[:role_ips]
      end

      def restart_app_servers
        @role_ips[:app].each do |app_ip|
          AWSUtilsV2.reboot_instance(app_ip)
        end
      end

      def restart_web_servers_one_by_one
        @role_ips[:web].each do |web_ip|
          deregister_instance(web_ip)
          restart_web_or_collapsed_server(web_ip)
          register_instance(web_ip)
          unless @role_ips[:web].last == web_ip
            #Wait for few seconds so that, the restarted web server starts processing requests, before deregistering the next web server.
            puts "Waiting.."
            sleep(60)
          end
        end
      end

      def start_backup_instance
        AWSUtilsV2.start_instance(@role_ips[:web_backup].first)
      end

      def stop_backup_instance
        AWSUtilsV2.stop_instance(@role_ips[:web_backup].first)
      end

      def register_instance(ip)
        backup_instance_id = AWSUtilsV2.get_ec2_instance(ip).instance_id
        elb_util = DeploymentUtils::ELBUtils::Manager.new(@environment)
        elb_util.register_instances_to_elb([backup_instance_id])
      end

      def deregister_instance(ip)
        current_instance_id = AWSUtilsV2.get_ec2_instance(ip).instance_id
        elb_util = DeploymentUtils::ELBUtils::Manager.new(@environment)
        elb_util.deregister_instance_from_elb([current_instance_id])
      end

      def switch_instances
        register_instance(@role_ips[:web_backup].first)
        #Wait for few seconds so that, the registered web server starts processing requests, before deregistering the next web server.
        puts "Waiting.."
        sleep 60
        deregister_instance(@role_ips[:web].first)
      end

      def revert_switch_instances
        register_instance(@role_ips[:web].first)
        #Wait for few seconds so that, the registered web server starts processing requests, before deregistering the next web server.
        puts "Waiting.."
        sleep 60
        deregister_instance(@role_ips[:web_backup].first)
      end

      def restart_web_or_collapsed_server(ip = @role_ips[:web].first)
        AWSUtilsV2.reboot_instance(ip)
      end
    end
  end
end