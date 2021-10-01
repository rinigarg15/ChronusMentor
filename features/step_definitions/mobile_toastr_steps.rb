And /^I clear (normal|notification) toastr$/ do |type|
  page.execute_script("#{get_toastr(type)}.remove()");
end

And /^I create a (normal|notification) toastr with text "(.*)"$/ do |type, message|
  page.execute_script("#{get_toastr(type)}.error('#{message}', '', #{get_toastr_options(type)})");
end

private

def get_toastr(type)
  case type
  when "normal"
    "toastr"
  when "notification"
    "notificationToastr"
  end
end

def get_toastr_options(type)
  case type
  when "normal"
    {}
  when "notification"
    {"containerId" => "push-notification-toast-container", "positionClass" => "toast-bottom-left"}.to_json.html_safe
  end
end