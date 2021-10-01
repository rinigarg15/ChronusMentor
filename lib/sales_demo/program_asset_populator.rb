module SalesDemo
  class ProgramAssetPopulator < BasePopulator
    REQUIRED_FIELDS = ProgramAsset.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:logo_updated_at, :banner_updated_at, :mobile_logo_updated_at, :created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :program_assets)
    end

    def copy_data
      self.reference.each do |ref_object|
        ProgramAsset.new.tap do |program_asset|
          assign_data(program_asset, ref_object)
          # program_id can be of Organization / Program, below branching maps with the correct object
          program_asset.program_id = master_populator.referer_hash[:organization][ref_object.program_id] || master_populator.referer_hash[:program][ref_object.program_id]
          handle_attachment_imports([:logo, :banner, :mobile_logo], program_asset, ref_object)
        end
      end
    end

    private

    def handle_attachment_imports(assets, program_asset, ref_object)
      assets.each do |asset|
        SolutionPack::AttachmentExportImportUtils.handle_attachment_import(
          SalesPopulator::ATTACHMENT_FOLDER + "program_assets/",
          program_asset,
          asset,
          program_asset.send("#{asset}_file_name"),
          ref_object.id
        )
      end
    end
  end
end