class SettingsExporter < SolutionPack::Exporter

  SettingAttributes = []
  AttrAccessors = []

  AssociatedExporters = ["ProgramSettingsExporter", "CalendarSettingExporter"]
  CareerDevAssociatedExporters = ["ProgramSettingsExporter"]
  FolderName = 'settings/'
  FileName = 'settings'

  def initialize(program, parent_exporter)
    self.objs = []
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  def export
    if self.class == SettingsExporter
      SolutionPack.create_if_not_exist_with_permission(solution_pack.base_path+FolderName, 0777)
      export_associated_content(self.program)
      export_features
    else
      CSV.open(self.solution_pack.base_path+FolderName+self.file_name+".csv", "wb") do |csv|
        columns = self.class::SettingAttributes.blank? ? self.class::AssociatedModel.constantize.column_names : self.class::SettingAttributes
        all_columns = columns + self.class::AttrAccessors
        csv << all_columns
        self.objs.each do |obj|
          attrs = obj.attributes
          data_column = []
          columns.each do |column|
            data_column << attrs[column]
          end
          unless self.class::AttrAccessors.blank?
            self.class::AttrAccessors.each do |attribute|
              data_column << obj.send(attribute)
            end
          end
          csv << data_column
        end
      end
    end
  end

  def export_features
    CSV.open(self.solution_pack.base_path+FolderName+"features.csv", "wb") do |csv|
      enabled_features = self.program.enabled_features
      disabled_features = self.program.disabled_features
      csv << enabled_features
      csv << disabled_features
    end
  end
end