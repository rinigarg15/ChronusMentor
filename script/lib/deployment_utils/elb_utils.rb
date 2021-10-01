require File.dirname(__FILE__) + '/aws_utils_v2'

module DeploymentUtils
  module ELBUtils
    class Manager
      def initialize(environment, options = {})
        AWSUtilsV2.initialize_aws_v2(options[:access_key_id], options[:secret_access_key], options[:region]) if options[:access_key_id] && options[:secret_access_key] && options[:region]
        @target_group_name = environment
        @elb_client = Aws::ElasticLoadBalancingV2::Client.new
      end

      def get_instance_ids_from_target_groups
        target_group_arn = get_target_group_arn
        return [] unless target_group_arn
        elb_targets = @elb_client.describe_target_health({target_group_arn: target_group_arn}).target_health_descriptions
        elb_targets = elb_targets.select{|target| target.target_health.state == "healthy"}
        elb_targets.map{|elb_target| elb_target.target.id}.uniq
      end

      def get_target_group_arn
        target_groups = @elb_client.describe_target_groups({
          names: [@target_group_name]
        })
        return target_groups.target_groups.first.target_group_arn
      rescue Aws::ElasticLoadBalancingV2::Errors::TargetGroupNotFound => e
        return false
      rescue => e
        raise "Error: #{e.message}"
      end

      def get_ips_from_instance_ids(instance_ids)
        ec2_client = Aws::EC2::Client.new
        instances = ec2_client.describe_instances({instance_ids: instance_ids})
        instance_reservations = instances.reservations.select{|reservation| reservation.instances[0].state.name == "running" }
        instance_reservations.collect{|reservation| reservation.instances[0].public_ip_address }
      end

      def get_elb_target_ips
        instance_ids = get_instance_ids_from_target_groups
        get_ips_from_instance_ids(instance_ids) unless instance_ids.empty?
      end

      def construct_targets_from_instance_ids(instance_ids)
        target_array = []
        instance_ids.each do |instance_id|
          target_array << {id: instance_id, port: 443}
        end
        target_array
      end

      def register_instances_to_elb(instance_ids)
        target_group_arn = get_target_group_arn
        unless target_group_arn
          puts "No ELB present for #{@target_group_name}"
          return target_group_arn
        end
        @elb_client.register_targets({
          target_group_arn: target_group_arn,
          targets: construct_targets_from_instance_ids(instance_ids)
        })
        puts "Registered #{instance_ids} as ELB Targets for #{@target_group_name}"
      rescue => e
        raise "Error: #{e.message}"
      end

      def deregister_instance_from_elb(instance_ids)
        target_group_arn = get_target_group_arn
        unless target_group_arn
          puts "No ELB present for #{@target_group_name}"
          return target_group_arn
        end
        targets = construct_targets_from_instance_ids(instance_ids)
        @elb_client.deregister_targets({
          target_group_arn: target_group_arn,
          targets: targets
        })
        puts "Deregistering #{instance_ids} from #{@target_group_name}"
        @elb_client.wait_until(:target_deregistered, {target_group_arn: target_group_arn, targets: targets})
        puts "Deregistered #{instance_ids} from #{@target_group_name}"
      rescue => e
        raise "Error: #{e.message}"
      end
    end
  end
end