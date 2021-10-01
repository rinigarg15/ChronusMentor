And /^(.*) in Career Development Programs Pane$/ do |step_definition|
  within("div.ibox", text: "Career Development Programs") do
    step step_definition
  end
end

And /^(.*) in Career Tracking Programs Pane$/ do |step_definition|
  within("div.ibox", text: "Career Tracking Programs") do
    step step_definition
  end
end