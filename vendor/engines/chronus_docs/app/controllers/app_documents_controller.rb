class AppDocumentsController < ::ApplicationController
  before_action :require_super_user

  # App document is only for super users. Its not a program specific feature.
  skip_action_callbacks_for_super_user_only_features

  def index
    @documents = ChronusDocs::AppDocument.all
  end

  def show
    @document = ChronusDocs::AppDocument.find(params[:id])
    send_data File.read(Rails.root.join("vendor/engines/chronus_docs/doc/app_documents/#{@document.title}.docx")), type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          :disposition => "attachment; filename=#{@document.title}.docx"
  end
end