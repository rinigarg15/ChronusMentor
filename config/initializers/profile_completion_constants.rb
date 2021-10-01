module ProfileCompletion
  module Score
    DEFAULT = 15
    PROFILE = 85
  end

  module Name    
    IMAGE = Proc.new {"feature.profile.content.upload_profile_pic".translate}
    MENTOR_PROFILE = Proc.new{|mentor_name| "feature.profile.content.complete_mentor_profile".translate(mentor_name: mentor_name)}
    MENTEE_PROFILE = Proc.new{|mentee_name| "feature.profile.content.complete_mentee_profile".translate(mentee_name: mentee_name)}
    EMPLOYEE_PROFILE = Proc.new{|employee_name| "feature.profile.content.complete_employee_profile".translate(employee_name: employee_name)}
  end

  PROMPT_LIMIT = 75
end