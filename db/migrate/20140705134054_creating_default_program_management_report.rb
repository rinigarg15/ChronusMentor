class CreatingDefaultProgramManagementReport< ActiveRecord::Migration[4.2]
  def up
    total_count = Program.active.count
    counter = 0
    Program.active.select('`programs`.`id`').find_each do |program|
      puts "Migrating for program with id #{program.id}..."
      Program.create_default_program_management_report(program.id)
      counter += 1
      puts "Completion: #{"%6.2f" % (counter*100.0/total_count)}%\n"
    end
  end

  def down
    Program.find_each do |program|
      program.abstract_views.where(default_view: AbstractView::DefaultType.default_program_management_report_type).find_each do |abstract_view|
        abstract_view.destroy
      end
      program.report_sections.where(default_section: Report::Section::DefaultSections.all_default_sections_in_order).find_each do |section|
        section.destroy
      end
    end
  end
end
