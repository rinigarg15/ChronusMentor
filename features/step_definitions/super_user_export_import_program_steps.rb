And /^I attach the exported pack to "([^\"]*)"$/ do |field|
  file_path = SolutionPack.last.attachment.path
  if (ENV['BS_RUN'] == 'true')
	  remote_file_detection(file_path)
  end 
  page.attach_file(field, file_path, visible: false)	
end