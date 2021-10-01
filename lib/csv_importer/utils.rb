module CsvImporter::Utils
  extend ActiveSupport::Concern
  
  def email(row)
    (row[UserCsvImport::CsvMapColumns::EMAIL.to_sym]||"").downcase
  end

  def downcase(list)
    list.map{|l| l.downcase}
  end

  def get_role(row)
    options[:role_names]||role_to_role_name_mapping(row[UserCsvImport::CsvMapColumns::ROLES.to_sym])
  end

  def role_to_role_name_mapping(roles)
    @role_to_role_name_mapping ||= program.roles.includes(:customized_term).inject({}){|hash, role| hash[role.customized_term.term.downcase] = role.name;hash}
    role_names = []
    downcase(roles.split(',').collect(&:strip).select(&:present?)).each{|role| role_names << @role_to_role_name_mapping[role]} if roles.present?
    return role_names
  end
end