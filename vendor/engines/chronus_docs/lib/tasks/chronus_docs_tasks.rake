namespace :app_documents do
  desc "Populates ChronusDocs::AppDocument records form the files present"
  # Right now, the rake task below populates for last default admin view.
  # We need to modify to populate variable number of views.
  task :populate_default_document_objects => [:environment] do
    dir_path = "#{Rails.root.to_s}/vendor/engines/chronus_docs/doc/app_documents"
    Dir.foreach(dir_path) do |file_name|
      next if file_name == '.' or file_name == '..'
      file_name = File.basename(file_name,File.extname(file_name)) 
      next if ChronusDocs::AppDocument.where(title: file_name).present?
      ChronusDocs::AppDocument.create!(title: file_name, description: file_name)
    end
  end
end