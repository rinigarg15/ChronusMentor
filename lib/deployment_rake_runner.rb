class DeploymentRakeRunner
  def self.add_rake_task(rake_task_name)
    ChrRakeTasks.create(name: rake_task_name)
  end

  def self.mark_as_failure(rake_obj)
    rake_obj.status = ChrRakeTasks::Status::FAILURE
    rake_obj.save!
  end

  def self.mark_as_success(rake_obj)
    rake_obj.status = ChrRakeTasks::Status::SUCCESS
    rake_obj.save!
  end

  def self.strip_inverted_commas(arg_name)
    arg_name.gsub!(/^\'|\'?$/, '').gsub!(/^\"|\"?$/, '')
  end

  def self.get_env_variables(env_var)
    env_hash = {}
    arr = env_var.split(/(?<=[\'|\"])\s/)
    arr.each do |elems|
      key, value = elems.split("=", 2)
      env_hash[key] = self.strip_inverted_commas(value)
    end
    env_hash
  end

  def self.fetch_and_execute
    rake_array = ChrRakeTasks.where(status: ChrRakeTasks::Status::PENDING)
    rake_array.each do |rake_obj|
      begin
        rake_task_name, env_var = (rake_obj.name).strip.split(" ",2)
        if env_var
          self.get_env_variables(env_var).each do |key, value|
            ENV[key] = value
          end
        end
        Rake::Task[rake_task_name].invoke
        Rake::Task[rake_task_name].reenable
      rescue => e
        self.mark_as_failure(rake_obj)
        raise e
      end
      self.mark_as_success(rake_obj)
    end
  end
end