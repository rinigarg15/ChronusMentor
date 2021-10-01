class CreateThreeSixty< ActiveRecord::Migration[4.2]
  def change
    create_table :three_sixty_competencies do |t|
      t.belongs_to :organization, :null => false
      t.string :title, :null => false
      t.text :description
      t.timestamps null: false
    end

    add_index :three_sixty_competencies, :organization_id

    create_table :three_sixty_questions do |t|
      t.belongs_to :three_sixty_competency, :null => false
      t.text :title, :null => false
      t.integer :question_type
      t.timestamps null: false
    end

    add_index :three_sixty_questions, :three_sixty_competency_id, :name => "index_three_sixty_questions_on_competency_id"

    create_table :three_sixty_surveys do |t|
      t.belongs_to :organization, :null => false
      t.string :title, :null => false
      t.text :description
      t.string :state
      t.date :expiry_date
      t.datetime :issue_date
      t.integer :threshold, :null => false
      t.timestamps null: false
    end

    add_index :three_sixty_surveys, :organization_id

    create_table :three_sixty_survey_competencies do |t|
      t.belongs_to :three_sixty_survey, :null => false
      t.belongs_to :three_sixty_competency, :null => false
      t.integer :position, :null => false
      t.timestamps null: false
    end

    add_index :three_sixty_survey_competencies, :three_sixty_survey_id, :name => "index_three_sixty_survey_comp_on_survey_id"

    create_table :three_sixty_survey_questions do |t|
      t.belongs_to :three_sixty_survey_competency, :null => false
      t.belongs_to :three_sixty_question, :null => false
      t.integer :position, :null => false
      t.timestamps null: false
    end

    add_index :three_sixty_survey_questions, :three_sixty_survey_competency_id, :name => "index_three_sixty_survey_ques_on_survey_comp_id"

    create_table :three_sixty_survey_assessees do |t|
      t.belongs_to :three_sixty_survey, :null => false
      t.belongs_to :member, :null => false
      t.timestamps null: false
    end

    add_index :three_sixty_survey_assessees, :three_sixty_survey_id, :name => "index_three_sixty_survey_assessees_on_survey_id"
    add_index :three_sixty_survey_assessees, :member_id, :name => "index_three_sixty_survey_assessees_on_member_id"

    create_table :three_sixty_survey_assessee_question_infos do |t|
      t.belongs_to :three_sixty_survey_assessee, :null => false
      t.belongs_to :three_sixty_question, :null => false
      t.float :average_value, :null => false, :default => 0.0
      t.integer :answer_count, :null => false, :default => 0
      t.timestamps null: false
    end

    add_index :three_sixty_survey_assessee_question_infos, :three_sixty_survey_assessee_id, :name => "index_three_sixty_asse_que_info_on_survey_assessee_id"
    add_index :three_sixty_survey_assessee_question_infos, :three_sixty_question_id, :name => "index_three_sixty_asse_que_info_on_question_id"

    create_table :three_sixty_reviewer_groups do |t|
      t.belongs_to :organization, :null => false
      t.string :name
      t.timestamps null: false
    end

    add_index :three_sixty_reviewer_groups, :organization_id

    create_table :three_sixty_survey_reviewer_groups do |t|
      t.belongs_to :three_sixty_survey, :null => false
      t.belongs_to :three_sixty_reviewer_group, :null => false
      t.timestamps null: false
    end

    add_index :three_sixty_survey_reviewer_groups, :three_sixty_survey_id, :name => "index_three_sixty_sur_revi_grp_on_survey_id"

    create_table :three_sixty_survey_reviewers do |t|
      t.belongs_to :three_sixty_survey_assessee, :null => false
      t.belongs_to :three_sixty_survey_reviewer_group, :null => false
      t.string :name
      t.string :email
      t.string :invitation_code
      t.boolean :invite_sent, :null => false, :default => false
      t.timestamps null: false
    end

    add_index :three_sixty_survey_reviewers, :three_sixty_survey_assessee_id, :name => "index_three_sixty_sur_reviewers_on_sur_assessee_id"

    create_table :three_sixty_survey_answers do |t|
      t.belongs_to :three_sixty_survey_question, :null => false
      t.belongs_to :three_sixty_survey_reviewer, :null => false
      t.text :answer_text
      t.integer :answer_value
      t.timestamps null: false
    end

    add_index :three_sixty_survey_answers, :three_sixty_survey_question_id, :name => "index_three_sixty_answer_on_sur_question_id"
    add_index :three_sixty_survey_answers, :three_sixty_survey_reviewer_id, :name => "index_three_sixty_answers_on_survey_reviewer_id"

    if Feature.count > 0
      Feature.create_default_features
    end

    Organization.active.each do |org|
      org.create_and_populate_default_three_sixty_settings!
    end
  end
end