class AddDefaultReportViewColumns< ActiveRecord::Migration[4.2]
  def up
    Program.all.each do |program|
      begin
        Program.create_demographic_report_view_colums!(program.id)
        puts "*** Created report view columns for #{program.name} ***"
      rescue => e
        say "Issue: Program name - #{program.name} #{e.message}", true
      end
    end
  end

  def down
  end
end
