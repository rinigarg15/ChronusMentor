class AddValueForAdminAccessType< ActiveRecord::Migration[4.2]
  def change
    programs_with_audited_access = Program.all.select{|prog| prog.has_feature?("confidentiality_audit_logs")}
    programs_with_audited_access.each do |prog|
      prog.admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
      prog.save!
    end
  end
end
