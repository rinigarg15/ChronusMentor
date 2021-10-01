Before('@javascript') do
    if ENV['AXE_RUN'] == 'true' 
      $file_var = File.open("#{WCAG_LOG_FILE}", "a")
    end  
end


module Axe
  class AccessibleExpectation
    def assert(page, matcher) 	
      begin
        $file_var.puts(page.driver.browser.current_url)
        $file_var.puts(matcher.failure_message) unless matcher.matches? page
      rescue Selenium::WebDriver::Error::UnhandledAlertError
        puts "Rescued UnhandledAlertError"
      end  
    end
  end
end

After('@javascript') do
  if ENV['AXE_RUN'] == 'true'
    $file_var.close
  end 
end
