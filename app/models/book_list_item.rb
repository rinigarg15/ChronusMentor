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

class BookListItem < ArticleListItem
  attr_accessor :presenter, :marked_as_new_item

  # Books have title
  def label_for_content
    "feature.article.header.title".translate
  end
end

