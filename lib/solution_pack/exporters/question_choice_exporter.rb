class QuestionChoiceExporter < SolutionPack::Exporter
  FileName = 'question_choice'
  AssociatedModel = "QuestionChoice"
  AssociatedExporters = []

  def initialize(program, parent_exporter)
    self.objs = collect_objects(parent_exporter)
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName + '_' + parent_exporter.file_name
    self.solution_pack = parent_exporter.solution_pack
  end

  private
  def collect_objects(parent_exporter)
    ref_obj_hash = {}
    parent_exporter.objs.each do |obj|
      next if obj.try(:matrix_question_id).present?
      klass_name = obj.class.base_class.name
      ref_obj_hash[klass_name] ||= []
      ref_obj_hash[klass_name] << obj.id
    end
    qcs = []
    ref_obj_hash.each do |ref_obj_type, id_arr|
      qcs += QuestionChoice.where(ref_obj_id: id_arr, ref_obj_type: ref_obj_type).default_choices.to_a
    end
    qcs
  end
end