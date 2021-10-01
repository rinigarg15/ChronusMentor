class CreateTranslationTablesForMentoringModel< ActiveRecord::Migration[4.2]
  def up
    MentoringModel.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})
    MentoringModel::TaskTemplate.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})
    MentoringModel::GoalTemplate.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})
    MentoringModel::MilestoneTemplate.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})

    MentoringModel::Task.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})
    MentoringModel::Goal.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})
    MentoringModel::Milestone.create_translation_table!({:title => :string, :description => :text}, {migrate_data: false})

    MentoringModel::FacilitationTemplate.create_translation_table!({:subject => :string, :message => :text}, {migrate_data: false})

    [MentoringModel, MentoringModel::TaskTemplate, MentoringModel::GoalTemplate, MentoringModel::MilestoneTemplate, MentoringModel::Task, MentoringModel::Goal, MentoringModel::Milestone].each do |klass|
      transition_objects = []
      counter = 0
      klass.select([:id, :title, :description]).find_each do |obj|
        transition = obj.translations.new(
          title: obj.read_attribute(:title, {:translated => false}),
          description: obj.read_attribute(:description, {:translated => false}),
          locale: I18n.default_locale
        )
        transition_objects << transition
        counter += 1
        if counter % 5000 == 0
          puts "Dumped #{counter - transition_objects.count} #{klass} objects into db. Dumping #{transition_objects.count} more."
          klass::Translation.import transition_objects, validate: false
          transition_objects = []
        end
      end
      puts "Dumped #{counter - transition_objects.count} #{klass} objects into db. Dumping #{transition_objects.count} more."
      klass::Translation.import transition_objects, validate: false unless transition_objects.empty?
    end

    transition_objects = []
    counter = 0
    MentoringModel::FacilitationTemplate.select([:id, :subject, :message]).find_each do |obj|
      transition = obj.translations.new(
        subject: obj.read_attribute(:subject, {:translated => false}),
        message: obj.read_attribute(:message, {:translated => false}),
        locale: I18n.default_locale
      )
      transition_objects << transition
      counter += 1
      if counter % 5000 == 0
          puts "Dumped #{counter - transition_objects.count} #{MentoringModel::FacilitationTemplate} objects into db. Dumping #{transition_objects.count} more."
        MentoringModel::FacilitationTemplate::Translation.import transition_objects, validate: false
        transition_objects = []
      end
    end
    puts "Dumped #{counter - transition_objects.count} #{MentoringModel::FacilitationTemplate} objects into db. Dumping #{transition_objects.count} more."
    MentoringModel::FacilitationTemplate::Translation.import transition_objects, validate: false unless transition_objects.empty?
  end

  def down
    MentoringModel.drop_translation_table! migrate_data: true
    MentoringModel::TaskTemplate.drop_translation_table! migrate_data: true
    MentoringModel::GoalTemplate.drop_translation_table! migrate_data: true
    MentoringModel::MilestoneTemplate.drop_translation_table! migrate_data: true

    MentoringModel::Task.drop_translation_table! migrate_data: true
    MentoringModel::Goal.drop_translation_table! migrate_data: true
    MentoringModel::Milestone.drop_translation_table! migrate_data: true

    MentoringModel::FacilitationTemplate.drop_translation_table! migrate_data: true
  end
end