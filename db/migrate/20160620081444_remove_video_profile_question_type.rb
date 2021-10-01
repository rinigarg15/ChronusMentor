class RemoveVideoProfileQuestionType< ActiveRecord::Migration[4.2]
  def up
    video_extensions = %w(application/mp4 video/mp4 video/vnd.objectvideo video/x-msvideo video/avi video/x-matroska video/x-ms-wmv video/mpeg video/quicktime video/x-flv video/webm video/ogg)
    ProfileAnswer.where(attachment_content_type: video_extensions).destroy_all
    Feature.where(name: "video_profile").each do |feature|
      feature.destroy
    end
  end

  def down
    # no down migration
  end
end
