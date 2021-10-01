def click_on_button button
  assert $driver.button(button)
  $driver.button(button).click
end

def wait_for_text_to_exist text
  assert $driver.text(text)
end

def fill_in_text name, text
  assert $driver.textfield(name)
  element =  $driver.textfield(name)
  element.send_keys text
end

def close_app
  $driver.close_app
end

def launch_app
  $driver.launch_app
end