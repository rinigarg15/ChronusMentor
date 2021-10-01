require File.dirname(__FILE__) + '/aws_utils_v2'

module DeploymentUtils
  module AppServerUtils
    class Manager
      def initialize(environment, options = {})
        AWSUtilsV2.initialize_aws_v2(options[:access_key_id], options[:secret_access_key], options[:region]) if options[:access_key_id] && options[:secret_access_key] && options[:region]
        @env_name = environment
        @primary_type = 'primary_app'
        @seconday_type = 'secondary_app'
      end

      def get_app_ips_based_on_tags
        @ec2_resource = Aws::EC2::Resource.new
        [get_primary_app_server_ips, get_secondary_app_server_ips]
      end

      def get_primary_app_server_ips
        get_ips(@primary_type)
      end

      def get_secondary_app_server_ips
        get_ips(@seconday_type)
      end

      def get_ips(server_type)
        instance_set = @ec2_resource.instances({filters: [{name: 'tag:Environment', values: [@env_name]}, {name: 'tag:ServerRole', values: [server_type]}]}) || []
        ips = []
        instance_set.each do |each_instance|
          ips << each_instance.public_ip_address if each_instance.state.name == "running"
        end
        ips
      end

      def update_server_role_tag(instance_ips, options = {})
        @client = Aws::EC2::Client.new
        role_name = options[:role_name]
        instance_ips.each do |instance_ip|
          instance_id = get_instance_id_from_ip_address(instance_ip)
          unless options[:role_name]
            server_role = get_tag_from_instance(instance_id)["ServerRole"]
            role_name = remove_temp_prefix(server_role)
          end
          update_tag(instance_id, role_name)
          puts "Tag updated for #{instance_ip} of #{@env_name} environment to #{role_name}"
        end
      rescue => e
        raise "Error: #{e.message}"
      end

      def update_tag(instance_id, role)
        @client.create_tags({
          resources: [
            instance_id, 
          ], 
          tags: [
            {
              key: "ServerRole", 
              value: role, 
            }, 
          ], 
        })
      end

      def get_instance_id_from_ip_address(instance_ip)
        @client.describe_addresses({public_ips: [instance_ip]}).first.addresses.first.instance_id
      end

      def get_tag_from_instance(instance_id)
        instance = Aws::EC2::Instance.new(
          id: instance_id
        )
        tags = {}
        instance.tags.each{|tag| tags[tag.key] = tag.value}
        tags
      end

      def remove_temp_prefix(temp_role)
        temp_role.gsub("temp_", "")
      end
    end
  end
end