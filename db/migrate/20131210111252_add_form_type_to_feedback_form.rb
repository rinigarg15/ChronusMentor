class AddFormTypeToFeedbackForm< ActiveRecord::Migration[4.2]
  def change
    add_column :feedback_forms, :form_type, :integer

    Organization.active.each do |org|
      org.programs.each do |program|
        program.feedback_forms.each do |feedback_form|
          feedback_form.form_type = Feedback::Form::Type::CONNECTION
          feedback_form.save!
        end
      end
    end

  end
end
