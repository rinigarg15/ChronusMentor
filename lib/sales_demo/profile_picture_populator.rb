module SalesDemo
  class ProfilePicturePopulator < BasePopulator
    REQUIRED_FIELDS = ProfilePicture.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:image_updated_at, :created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :profile_pictures)
    end

    def copy_data
      self.reference.each do |ref_object|
        ProfilePicture.new.tap do |profile_picture|
          assign_data(profile_picture, ref_object)
          profile_picture.member_id = master_populator.referer_hash[:member][ref_object.member_id]
          # Profile Picture will be saved inside  handle_attachment_import
          SolutionPack::AttachmentExportImportUtils.handle_attachment_import(SalesPopulator::ATTACHMENT_FOLDER + "profile_pictures/", profile_picture, :image, profile_picture.image_file_name, ref_object.id)
        end
      end
    end
  end
end