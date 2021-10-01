# == Schema Information
#
# Table name: ckeditor_assets
#
#  id                :integer          not null, primary key
#  data_file_name    :string(255)      not null
#  data_content_type :string(255)
#  data_file_size    :integer
#  assetable_id      :integer
#  assetable_type    :string(30)
#  type              :string(25)
#  guid              :string(10)
#  locale            :integer          default(0)
#  program_id        :integer
#  created_at        :datetime
#  updated_at        :datetime
#  login_required    :boolean          default(FALSE)
#

class Ckeditor::Asset < ActiveRecord::Base
  include Ckeditor::Orm::ActiveRecord::AssetBase
  include Ckeditor::Backend::Paperclip

  belongs_to_organization

  def path_for_ckeditor_asset
    (Rails.env.development? || Rails.env.test?) ? "#{Rails.root}/public#{self.url}" : { bucket_name: self.data.s3_object.bucket_name, key: self.data.s3_object.key, region: S3_REGION }.to_yaml
  end
end
