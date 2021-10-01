class FileUploadsController < ApplicationController
  skip_before_action :require_program, :login_required_in_program

  def create
    file_upload_options = get_file_upload_options
    @file_uploader = FileUploader.new(params[:type_id], params[:owner_id], params[:file], file_upload_options)
    if @file_uploader.save
      render json: @file_uploader.uniq_code.to_json
    else
      render json: @file_uploader.errors.to_json, status: 403
    end
  end

  private

  def get_file_upload_options
    return DROPZONE::DEFAULT_FILE_UPLOAD_OPTIONS unless params[:uploaded_class].present?
    FileUploader.get_file_upload_options(params[:uploaded_class].to_s, params)
  end
end