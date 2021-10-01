module OrganizationData
  module S3AssetsCollectionExtensions

    def self.collect_s3_assets_for_model(parent_class, ids = [], operation = nil, s3_asset_collect_csv)
      keys = get_keys_with_attachments(parent_class)
      keys.each do |key|
        attachment_path = Paperclip::AttachmentRegistry.definitions_for(parent_class)[key.to_sym].try(:[], :path)
        from_translations = attachment_path.present? && attachment_path.include?(":translation_id")
        ((operation == OrganizationData::TargetCollection::OPERATION::COLLECT_S3_ASSETS) ? parent_class : parent_class.where(id: ids)).find_each(batch_size: 50000) do |obj|
          print "."
          if from_translations.present?
            collect_s3_assets_from_translations(parent_class.name, obj, key, from_translations, s3_asset_collect_csv)
          else
            populate_s3_assets_csv(parent_class.name, obj, key, from_translations, s3_asset_collect_csv)
          end
        end
        puts "#{key}"
      end
    end

    private
    #getting all the attributes from subclasses also
    #For eg: Ckeditor::Asset has Ckeditor::AttachmentFile and Ckeditor::Picture as subclasses. Therefore,  the parent is not registered with paperclip registry and we have to get all the subclasses to find the keys
    def self.get_keys_with_attachments(parent_class, keys = [])
      parent_class.subclasses.each do |sub_class|
        keys = get_keys_with_attachments(sub_class, keys)
      end
      keys = keys | Paperclip::AttachmentRegistry.definitions_for(parent_class).keys
    end

    def self.collect_s3_assets_from_translations(model_name, object, key, from_translations, s3_asset_collect_csv)
      locales = object.translations.pluck("DISTINCT locale")
      current_locale = I18n.locale
      locales.each do |locale|
        I18n.locale = locale
        object.reload
        populate_s3_assets_csv(model_name, object, key, from_translations, s3_asset_collect_csv)
      end
      I18n.locale = current_locale
    end

    def self.populate_s3_assets_csv(model_name, object, key, from_translations = false, s3_asset_collect_csv)
      object_id = from_translations.present? ? object.translation.id : object.id
      model_name += "::Translation" if from_translations.present?
      attachment = object.send(key)
      if attachment.present?
        #By default, :original style is present, in addition to that, we have to delete attachments of other styles also
        styles = [:original, attachment.styles.keys].uniq.flatten
        styles.each do |style|
          s3_asset_collect_csv << [attachment.options[:bucket], attachment.path(style), model_name, object_id, key]
        end
      end
    end
  end
end
