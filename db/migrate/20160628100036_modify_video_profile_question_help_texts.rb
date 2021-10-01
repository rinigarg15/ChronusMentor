class ModifyVideoProfileQuestionHelpTexts< ActiveRecord::Migration[4.2]
  def up
    ProfileQuestion.where(help_text: "Please upload a file of the following types: pdf, doc, xls, ppt, docx, pptx, xlsx (File size limit is 2MB) or mp4, avi, mkv, wmv, mpeg, flv, webm, ogg  (File size limit is 50MB)").each do |pq|
      pq.help_text = "Please upload a file of the following types: pdf, doc, xls, ppt, docx, pptx, xlsx (File size limit is 2MB)"
      pq.save!
    end
  end

  def down
    # No down migration
  end
end
