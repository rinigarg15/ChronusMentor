class MultipleServersUtils
  EMAIL_RECIPIENTS = ["monitor+sendmail@chronus.com"]
  PAGERDUTY_RECIPIENTS = ["multiple-servers@apollo.pagerduty.com"]

  def self.detect_multiple_servers_running
    if multiple_servers_running?
      recipients = (defined?(PAGERDUTY_NOTIFICATION) && PAGERDUTY_NOTIFICATION) ? PAGERDUTY_RECIPIENTS : EMAIL_RECIPIENTS
      InternalMailer.notify_multiple_servers(recipients).deliver_now
    end
  end

  def self.get_servers_count(server_types=["primary_app"])
    return 1 if (Rails.env.development? || Rails.env.test?)
    ec2_resource = get_ec2_resource
    ec2_resource.instances({filters: [{name: 'tag:Environment', values: [Rails.env]}, {name: 'tag:ServerRole', values: server_types}, {name: "instance-state-name" , values: ["running"]}]}).count
  end

  private
  
  def self.multiple_servers_running?
    env_config = get_env_config
    ec2_resource = get_ec2_resource
    server_role = env_config["collapsed"] ? "collapsed" : "primary_app"
    instance_set = ec2_resource.instances({filters: [{name: 'tag:Environment', values: [Rails.env]}, {name: 'tag:ServerRole', values: [server_role]}]}) || []
    count = 0

    running_instances = instance_set.select{|instance| instance.state.name == "running"}
    running_instances.count > 1
  end

  def self.get_env_config
    YAML.load_file(File.dirname(__FILE__) +'/../config/deploy.yml')[Rails.env]
  end

  def self.get_ec2_resource
    if (Rails.env.development? || Rails.env.test?)
      aws_options = {access_key_id: ENV["S3_KEY"], secret_access_key: ENV["S3_SECRET"]}
    else
      aws_options = {region: AWS_ES_OPTIONS[:es_region]}
    end
    Aws::EC2::Resource.new(aws_options)
  end
end