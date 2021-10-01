class CucumberLog
  # This routine is neccessary since puts is overridden by cucumber in scenario hooks and 
  # causes problem in sequencing of logs
  def self.log(str)
    puts str
  end
end

# This class provides a way to control GC when running integration tests using cucumber. 
# The default GC behaviour causes ruby crashes (segmentation fault) when the full 
# integration suite is run within a single cucumber session. e.g cucumber features
# Adapted from http://37signals.com/svn/posts/2742-the-road-to-faster-tests and 
# http://www.rubyinside.com/careful-cutting-to-get-faster-rspec-runs-with-rails-5207.html
#
# Notes:
# 1. Calling GC during Before and After Hooks of cucumber scenarions didn't avoid the ruby 
#    crash since default GC can run during long running scenarios. Hence spawned a new 
#    thread to reasonably guarantee that GC is called once in 'X' seconds.
#
# 2. Our unit/test_help.rb does also controls GC during unit and functional tests

class CucumberDeferredGC
  @@deferred_gc_threshold = (ENV['DEFER_GC'] || 5.0).to_f
  @@started = false

  def self.process_size()
    ((`ps -o rss= -p "#{Process.pid}"`.to_i) / 1024.0).to_i
  end

  def self.start
    unless @@deferred_gc_threshold > 0
      CucumberLog.log "#{self.name}.start : Skipping CucumberDeferredGC"
      return
    end

    Thread.new do
      Thread.current["name"] = "#{self.name}-Thread"
      begin
        while true do
          # puts "#{Thread.current["name"]} : About to sleep..."
          sleep @@deferred_gc_threshold
          self.reconsider
        end
      rescue
        CucumberLog.log "#{Thread.current["name"]} : Error #{$!}"
      ensure
      end
    end

    @@started = true
  end

  def self.reconsider
    return unless @@started && @@deferred_gc_threshold > 0
    GC.enable
    GC.start
    GC.disable
    # CucumberLog.log "#{self.name}.reconsider : end last_gc_run = #{@@last_gc_run}"
  end
end

# Class used to avoid using timeouts in cucumber and capybara steps.
# Adapted from links 
#   http://go-gaga-over-testing.blogspot.in/2011/01/selenium-wait-for-ajax-right-way-agile.html
#   http://stackoverflow.com/questions/6047124/waitforelement-with-cucumber-selenium
# This approache need to revisited when upgrading to capybara 2.0.0. See the below link
#   http://www.elabs.se/blog/53-why-wait_until-was-removed-from-capybara
class CucumberAjaxCallTracker
  def self.enabled?
    return (ENV['CUCUMBER_ENV'] && !ENV['CUCUMBER_DISABLE_PENDING_AJAX_CHECKS'])
  end

  def self.wait_till_ajax_calls_complete(page)
    begin
      wait_count_limit = CucumberWait.get_wait_count_limit
      wait_interval = CucumberWait.get_wait_interval

      return unless page.evaluate_script('window.cucumber_page_load_begin')
      check_count = wait_count_limit
      while (!page.evaluate_script('window.cucumber_page_load_end') && check_count > 0) do
        check_count -= 1
        sleep wait_interval
      end  
      if check_count <= 0
        CucumberLog.log "#{self.name} : page load did not complete in #{wait_count_limit*wait_interval} seconds"
        return
      elsif check_count < wait_count_limit
        CucumberLog.log "#{self.name} : page load completed in #{check_count*wait_interval} seconds"
      end

      pending_ajax_calls = 0
      while ((pending_ajax_calls = page.evaluate_script('jQuery.active') + page.evaluate_script('Ajax.activeRequestCount'))) > 0 && check_count > 0 
        check_count -= 1
        sleep wait_interval
      end    
        
      if check_count <= 0 && pending_ajax_calls > 0
        CucumberLog.log "#{self.name} : pending ajax calls (#{pending_ajax_calls}) did not complete in #{wait_count_limit*wait_interval} seconds"
      end
    rescue => e
      CucumberLog.log "#{self.name} : Exception : #{e.message} \n" + e.backtrace.join("\n")
      raise e
    end
  end
end

class CucumberWait 
  @@max_check_count = 200
  @@sleep_interval = 0.05

  def self.set_default_wait_time(wait_time)
    @@max_check_count = (wait_time / @@sleep_interval).to_i
  end

  def self.get_wait_count_limit
    @@max_check_count
  end

  def self.get_wait_interval
    @@sleep_interval
  end

  # Fix for cucumber failures due to - Element is not currently visible and so may not be interacted with (Selenium::WebDriver::Error::ElementNotVisibleError)
  # See link at https://github.com/jnicklas/capybara/issues/761
  def self.retry_until_element_is_visible
    wait_count_limit = CucumberWait.get_wait_count_limit
    wait_interval = CucumberWait.get_wait_interval
    check_count = wait_count_limit

    begin
      yield
    rescue => e
      raise e unless e.class == Selenium::WebDriver::Error::ElementNotVisibleError
      if (check_count <= 0)
        CucumberLog.log "#{self.name} : Element did not become visible within #{wait_count_limit*wait_interval} seconds" 
        raise e
      end
      CucumberLog.log "#{self.name} : Element is not visible . Will retry in #{wait_interval} seconds"
      sleep wait_interval
      check_count -= 1
      retry
    ensure
      CucumberLog.log "#{self.name} : Element became visible in #{(wait_count_limit - check_count)*wait_interval} seconds" if check_count < wait_count_limit
    end
  end
end