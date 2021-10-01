class AddDefaultMentorRequestStyle< ActiveRecord::Migration[4.2]
  def up
    change_column_default :programs, :mentor_request_style, Program::MentorRequestStyle::NONE
    Program.where(mentor_request_style: nil).update_all(mentor_request_style: Program::MentorRequestStyle::NONE)
  end

  def down
    # Nothing
  end
end
