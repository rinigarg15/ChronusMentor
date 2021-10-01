class RemoveSkypeHelperText< ActiveRecord::Migration[4.2]
  def change
    default_text_1 = "Your skype status will be shown only to connected members. Please make sure you have enabled the <a href='http://forum.skype.com/index.php?s=&amp;showtopic=60479&amp;view=findpost&amp;p=1475951' target='blank'> skype privacy setting </a> for showing your online web status."


    default_text_2 = "Your skype status will be shown only to connected members. Please make sure you have enabled the <a href='http://forum.skype.com/index.php?s=&showtopic=60479&view=findpost&p=1475951' target='blank'>skype privacy setting</a> for showing your online web status."

    default_text_3 = "Your skype status will be shown only to connected members. Please make sure you have enabled the <a href=\"http://forum.skype.com/index.php?s=&amp;showtopic=60479&amp;view=findpost&amp;p=1475951\" target=\"blank\">skype privacy setting</a> for showing your online web status."

    ProfileQuestion.skype_question.where(:help_text => [default_text_1, default_text_2, default_text_3]).each do |profile_question|
      profile_question.update_attributes!(:help_text => "Including Skype id in your profile would allow your connected members to call you from the mentoring area. If you face trouble receiving Skype calls, please check your privacy settings.")
    end
  end
end

 
 

 