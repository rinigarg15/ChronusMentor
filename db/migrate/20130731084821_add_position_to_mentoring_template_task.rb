class AddPositionToMentoringTemplateTask< ActiveRecord::Migration[4.2]

  def change
    add_column :mentoring_template_tasks, :position, :integer

    # MentoringTemplate::Task.reset_column_information          #Reload the model info
    # MentoringTemplate.transaction do
    #   MentoringTemplate.all.each do |mt|
    #     mt.milestones.each do |mtm|
    #       mtm.tasks.each_with_index do |mtt, i|
    #         mtt.position = i+1
    #         mtt.save!
    #       end
    #     end
    #   end
    # end
  end
end