require_relative './deployment_helper'
require_relative './deployment_constants'
require 'colorize'

class StepChecker
  def self.new_dictionary_value
    {
      :timestamp => "",
      :send_mail => false,
      :verify_build_check => false,
      :diff_master_develop => false,
      :diff_present_checker => [],
      :create_review => false,
      :start_maintenance => [],
      :completed_deployment => [],
      :completed_rake_tasks => [],
      :store_logs => [],
      :perform_recovery_setup => []
    }
  end

  def self.write_retry_file(steps)
    File.write(RETRY_DEPLOYMENT_STEPS_FILE, steps)
  end

  def self.get_hash_from_file
    eval(File.read(RETRY_DEPLOYMENT_STEPS_FILE))
  end

  def self.get_value(key)
    step_checker_lock do
      self.get_hash_from_file[key]
    end
  end

  def self.step_checker_lock
    while !system("mkdir /tmp/deployment_lock") #Allow to update deployment_steps_file one at a time
      puts "Wait: Some other function is updating deployment step check file!"
      sleep rand(5)
    end
    begin
      return yield
    rescue => e
      puts "Error: failure in updating deployment step check file. Exception: #{e.message}".colorize(:color => :red)
    ensure
      system("rm -r /tmp/deployment_lock")
    end
  end

  def self.update_file(key, value)
    step_checker_lock do
      steps = self.get_hash_from_file
      if steps[key].class == Array
        if value.class == Array
          steps[key] += value
        else
          steps[key].push(value)
        end
      else
        steps[key] = value
      end
      self.write_retry_file(steps)
    end
  end
end