# == Schema Information
#
# Table name: article_list_items
#
#  id                 :integer          not null, primary key
#  type               :string(255)
#  content            :text(65535)
#  description        :text(65535)
#  created_at         :datetime
#  updated_at         :datetime
#  article_content_id :integer
#

class SiteListItem < ArticleListItem
  validate :check_if_url_has_right_format
  attr_accessor :marked_as_new_item

  # Website has URL
  def label_for_content
    "feature.article.header.url".translate
  end

  protected
  def check_if_url_has_right_format
    return unless self.content
    begin
      uri_class = URI.parse(self.content).class
      unless (uri_class == URI::HTTP || uri_class == URI::HTTPS)
        self.errors.add(:content, "activerecord.errors.models.site_list_item.attributes.content.invalid_url".translate) and return
      end
    rescue
      errors.add(:content, "activerecord.errors.models.site_list_item.attributes.content.invalid_url".translate)
    end
  end
end
