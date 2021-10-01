class MigrateToRoleQuestionPrivacySettings< ActiveRecord::Migration[4.2]
  def up
    id31 = RoleQuestion.where('private = 31').pluck(:id) #Viewable by all
    id16 = RoleQuestion.where('private = 16').pluck(:id) #Viewable only by Admins
    id3116 = (id31 + id16)

    id87 = RoleQuestion.where('private & 8 = 8 and private & 7 = 0').pluck(:id) - (id3116) #Viewable only by Admins and the user
    id311687 = (id3116 + id87).uniq

    id1 = RoleQuestion.where('(private & 1) = 1').pluck(:id) - id311687 #Viewable only by all Mentees of program
    id2 = RoleQuestion.where('(private & 2) = 2').pluck(:id) - id311687 #Viewable only by all Mentors of program
    id3 = RoleQuestion.where('(private & 4) = 4').pluck(:id) - id311687 #Viewable only by all connected members of the user
    id123 = (id1 + id2 + id3).uniq

    program_role_ids = Role.where(name: RoleConstants::MENTOR_NAME).select("id, program_id")
    mentor_hash ={}
    program_role_ids.each{|a| mentor_hash[a[:program_id]]=a[:id]}

    program_role_ids = Role.where(name: RoleConstants::STUDENT_NAME).select("id, program_id")
    student_hash ={}
    program_role_ids.each{|a| student_hash[a[:program_id]]=a[:id]}
    
    ####################################
    # Student privacy setting
    ####################################
    privacy_settings = []
    program_id_of_role_questions = RoleQuestion.joins(:role).where(id: id1).select('roles.program_id, role_questions.id')
    ids = ActiveRecord::Base.connection.select_all(program_id_of_role_questions)
    ids.each do |hash|
      privacy_settings << RoleQuestionPrivacySetting.new(role_question_id: hash['id'], role_id: student_hash[hash['program_id']], setting_type: RoleQuestionPrivacySetting::SettingType::ROLE)
    end

    ####################################
    # Mentor privacy setting
    ####################################    
    program_id_of_role_questions = RoleQuestion.joins(:role).where(id: id2).select('roles.program_id, role_questions.id')
    ids = ActiveRecord::Base.connection.select_all(program_id_of_role_questions)

    ids.each do |hash|
      privacy_settings << RoleQuestionPrivacySetting.new(role_question_id: hash['id'], role_id: mentor_hash[hash['program_id']], setting_type: RoleQuestionPrivacySetting::SettingType::ROLE)        
    end

    ####################################
    # Connected Member privacy setting
    ####################################
    
    id3.each do |q_id|
      privacy_settings << RoleQuestionPrivacySetting.new(role_question_id: q_id, setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    end

    RoleQuestionPrivacySetting.import privacy_settings, validate: false
   
    RoleQuestion.where(id: id31).update_all(private: 1)
    RoleQuestion.where(id: id16).update_all(private: 3)
    RoleQuestion.where(id: id87).update_all(private: 4)
    RoleQuestion.where(id: id123).update_all(private: 2)
  end

  def down
  end
end



