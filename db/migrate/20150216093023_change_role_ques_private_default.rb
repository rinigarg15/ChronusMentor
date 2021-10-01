class ChangeRoleQuesPrivateDefault< ActiveRecord::Migration[4.2]
  def up
    change_column :role_questions, :private, :integer, :default => 31

    RoleQuestion.reset_column_information
    RoleQuestion.where(private: 0).update_all(private: 31) 
    RoleQuestion.where(private: 1).update_all(private: 28) 
    RoleQuestion.where(private: 2).update_all(private: 24) 
    RoleQuestion.where(private: 3).update_all(private: 26) 
    RoleQuestion.where(private: 4).update_all(private: 16) 
  end

  def down
    change_column :role_questions, :private, :integer, :default => 0

    RoleQuestion.reset_column_information
    RoleQuestion.where(private: 31).update_all(private: 0) 
    RoleQuestion.where(private: 28).update_all(private: 1) 
    RoleQuestion.where(private: 24).update_all(private: 2) 
    RoleQuestion.where(private: 26).update_all(private: 3) 
    RoleQuestion.where(private: 16).update_all(private: 4) 
    RoleQuestion.where("private NOT IN (?)", [0, 1, 2, 3, 4]).update_all(private: 0)
  end
end
