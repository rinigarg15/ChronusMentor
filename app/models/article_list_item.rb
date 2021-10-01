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

class ArticleListItem < ActiveRecord::Base
  module TypeToString
    BookListItem = "book_list_item"
    SiteListItem = "site_list_item"

    def self.all
      [TypeToString::BookListItem, TypeToString::SiteListItem]
    end
  end

  belongs_to :article_content
  validates_presence_of :content, :type

  def self.valid_types
    [BookListItem, SiteListItem]
  end

  def self.valid_types_as_strings
    valid_types.map(&:name)
  end

  def type_string
    self.type.to_s    
  end
  
  def type_string=(arg)
    self.type = arg
  end
end
