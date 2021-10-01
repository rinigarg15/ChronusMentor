module AWSUtilsV2
  def self.initialize_aws_v2(access_key, secret_key, region)
    cred = Aws::Credentials.new(access_key, secret_key)
    Aws.config.update({ 
      region: region,
      credentials: cred
    })
  end

  def self.initialize_ec2_client
    @ec2 = Aws::EC2::Client.new
  end

  def self.get_ec2_instance(ip)
    initialize_ec2_client
    @ec2.describe_instances(filters: [{name:'ip-address', values:[ip]}]).reservations[0].instances[0]
  rescue => e
    raise "Error: #{e.message}"
  end

  def self.start_instance(ip)
    ec2_instance = get_ec2_instance(ip)
    if ec2_instance.state.name == "stopped"
      @ec2.start_instances({instance_ids: [ec2_instance.instance_id]})
      @ec2.wait_until(:instance_running, instance_ids: [ec2_instance.instance_id])
      puts "Instance of ip #{ip} started"
    else
      puts "Instance of ip #{ip} already started"
    end
    return ec2_instance.instance_id
  rescue => e
    raise "Error: #{e.message}"
  end

  def self.reboot_instance(ip)
    ec2_instance = get_ec2_instance(ip)
    if ec2_instance.state.name == "running"
      if agree("Reboot instance with ip #{ip} y/n?")
        @ec2.reboot_instances({instance_ids: [ec2_instance.instance_id]})
        sleep 30
        puts "Instance of ip #{ip} rebooted"
      end
    else
      puts "Instance of ip #{ip} is in stopped state"
    end
    return ec2_instance.instance_id
  rescue => e
    raise "Error: #{e.message}"
  end

  def self.stop_instance(ip)
    ec2_instance = get_ec2_instance(ip)
    if ec2_instance.state.name == "running"
      @ec2.stop_instances({instance_ids: [ec2_instance.instance_id]})
      @ec2.wait_until(:instance_stopped, instance_ids: [ec2_instance.instance_id])
      puts "Instance of ip #{ip} stopped"
    else
      puts "Instance of ip #{ip} already stopped"
    end
    return ec2_instance.instance_id
  rescue => e
    raise "Error: #{e.message}"
  end
end