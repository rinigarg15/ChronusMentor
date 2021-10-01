class CreateDefaultReportViewColumns< ActiveRecord::Migration[4.2]
  def up
    Program.all.each do |program|
      Program.create_default_group_report_view_colums!(program.id)
      puts "*** Created report view columns for #{program.name} ***"
    end
  end

  def down
  end
end