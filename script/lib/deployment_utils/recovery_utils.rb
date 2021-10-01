require File.dirname(__FILE__) + '/aws_utils_v2'
require File.dirname(__FILE__) + '/elb_utils'

module DeploymentUtils
  module RecoveryUtils
    class Manager
      attr_accessor :instance, :backup_instance
      def initialize(rails_env, type, options = {})
        AWSUtilsV2.initialize_aws_v2(options[:access_key_id], options[:secret_access_key], options[:region]) if options[:access_key_id] && options[:secret_access_key] && options[:region]
        @ec2 = Aws::EC2::Client.new
        @primary_ip = options[:primary_ip]
        @backup_ips = options[:backup_ips]
        @rails_env = rails_env
        @server_type = type
      end

      def perform_recovery_steps
        initialize_primary_and_backup_instances
        create_snapshot
        @backup_instances.each do |backup_instance|
          new_volume = create_volume(backup_instance)
          old_volume = detach_backup_volume(backup_instance)
          attach_new_backup_volume(backup_instance, new_volume)
          cleanup_old_snapshot_and_volume(old_volume) if old_volume
        end
      end

      def initialize_primary_and_backup_instances
        @primary_instance = @ec2.describe_instances(filters: [{name:'ip-address', values:[@primary_ip]}]).reservations[0].instances[0]
        @backup_instances = @ec2.describe_instances(filters: [{name:'ip-address', values:@backup_ips}]).reservations.collect{|reservation| reservation.instances[0]}
        @mnt_ebs_volume = @ec2.describe_volumes(filters: [{name:'attachment.instance-id', values: [@primary_instance.instance_id]}, {name: 'attachment.device', values:["/dev/xvdi"]}]).volumes.first
      end

      def create_snapshot
        puts "Creating Snapshot"
        create_snapshot_req = @ec2.create_snapshot({volume_id: @mnt_ebs_volume.volume_id, description: "Recovery Snapshot #{@rails_env} #{@server_type} Server"})
        @snapshot = @ec2.describe_snapshots(filters: [{name:'snapshot-id', values:[create_snapshot_req.snapshot_id]}]).snapshots.first
        @ec2.wait_until(:snapshot_completed, snapshot_ids: [@snapshot.snapshot_id]) do |wait_config|
          wait_config.max_attempts = 750
          wait_config.delay = 5
        end
        puts "Created Snapshot #{@snapshot.snapshot_id}"
      end

      def create_volume(backup_instance)
        puts "Creating Volume"
        new_volume = @ec2.create_volume({snapshot_id: @snapshot.snapshot_id, availability_zone: backup_instance.placement.availability_zone, volume_type: "gp2"})
        result = @ec2.wait_until(:volume_available, volume_ids: [new_volume.volume_id])
        @ec2.create_tags(resources: [new_volume.volume_id], tags: [{key: "recovery" , value: "Recovery Volume #{@rails_env} #{@server_type} Server"}])
        puts "Created Volume #{new_volume.volume_id}"
        new_volume
      end

      def detach_backup_volume(backup_instance)
        backup_machine_volume = @ec2.describe_volumes(filters: [{name:'attachment.instance-id', values: [backup_instance.instance_id]}, {name: 'attachment.device', values:["/dev/xvdi"]}]).volumes.first

        if backup_machine_volume
          puts "Detaching old volume #{backup_machine_volume.volume_id}"
          @ec2.detach_volume(instance_id: backup_instance.instance_id, volume_id: backup_machine_volume.volume_id)
          @ec2.wait_until(:volume_available, volume_ids: [backup_machine_volume.volume_id])
          puts "Detached volume"
        end
        backup_machine_volume
      end

      def attach_new_backup_volume(backup_instance, new_volume)
        puts "Attaching new volume to backup machine"
        @ec2.attach_volume(instance_id: backup_instance.instance_id, volume_id: new_volume.volume_id, device: "/dev/xvdi")
        @ec2.wait_until(:volume_in_use, volume_ids: [new_volume.volume_id])
        puts "Attached new volume #{new_volume.volume_id} to backup machine #{backup_instance.public_ip_address}"
      end

      def cleanup_old_snapshot_and_volume(old_volume)
        puts "Cleaning up old snapshot and volume"
        backup_snapshot_id = old_volume.snapshot_id
        backup_snapshot = @ec2.describe_snapshots(filters: [{name:'snapshot-id', values: [backup_snapshot_id]}]).snapshots
        @ec2.delete_snapshot({snapshot_id: backup_snapshot_id}) unless backup_snapshot.empty?
        if old_volume
          @ec2.delete_volume({volume_id: old_volume.volume_id})
          @ec2.wait_until(:volume_deleted, volume_ids: [old_volume.volume_id])
        end
      rescue Exception => e
        puts "Couldnt cleanup snapshots, please remove any old volume and snapshot which was attached to backup volume if it exists"
      end

      def associate_address_ec2(eip_desc_1, eip_desc_2)
        if eip_desc_1.instance_id
          @ec2.associate_address({instance_id: eip_desc_1.instance_id, allocation_id: eip_desc_2.allocation_id})
          puts "#{eip_desc_2.public_ip} attached to #{eip_desc_1.instance_id}"
        end
      end

      def disassociate_address_ec2(eip_desc)
        @ec2.disassociate_address({association_id: eip_desc.association_id}) if eip_desc.instance_id
      end

      def switch_or_attach_ips(ip1, ip2)
        eip_desc_1 = @ec2.describe_addresses({public_ips: [ip1]}).first.addresses.first
        eip_desc_2 = @ec2.describe_addresses({public_ips: [ip2]}).first.addresses.first
        #Disassociating existing IPs from instance ids
        disassociate_address_ec2(eip_desc_1)
        disassociate_address_ec2(eip_desc_2)
        #Switching IPs
        associate_address_ec2(eip_desc_1, eip_desc_2)
        associate_address_ec2(eip_desc_2, eip_desc_1)

      rescue => e
        puts "Error on assigning IPs. Do it manually"
      end

      def recover_backup_instance(backup_ip)
        puts "Starting server #{backup_ip} of type #{@server_type}"
        backup_instance_id = AWSUtilsV2.start_instance(backup_ip)
        elb_util = DeploymentUtils::ELBUtils::Manager.new(@rails_env)
        elb_util.register_instances_to_elb([backup_instance_id]) unless @server_type.include?("app")
      end

    end
  end
end