class BookListItemPresenter
  attr_accessor :image_link, :rating, :author, :list_item, :amazon_link, :title
  
  def initialize(book_list_item)
    # TODO - explore Good Reads and replace it with amazon book search
    res = BookListItemPresenter.get_search_response_from_amazon(book_list_item.content)

    if res && res.items
      # First filter those items which have the exact name
      likely_items = res.items.select do |i|
        BookListItemPresenter.similar_book_titles?(i.get("ItemAttributes/Title"), book_list_item.content)
      end
      selected_item = likely_items.first
      likely_items.each do |item|
        # Override the selected one with an item that has image and amazon link
        if (BookListItemPresenter.get_image_url(item) && item.get("DetailPageURL"))
          selected_item = item
          break
        end
      end
      if selected_item
        image_url = BookListItemPresenter.get_image_url(selected_item)
        self.image_link = Rails.application.config.force_ssl ? get_book_cover_ssl_url(image_url) : image_url 
        self.author = selected_item.get("ItemAttributes/Author")
        self.amazon_link = selected_item.get("DetailPageURL")
        self.title = selected_item.get("ItemAttributes/Title")
      end
    end

    self.list_item = book_list_item
  end

  def self.similar_book_titles?(str1, str2)
    (str1 && str2 && (process(str1) == process(str2)))
  end

  def self.get_image_url(item)
    image_hash = item.get_hash("MediumImage")
    image_hash.present? ? image_hash["URL"] : nil
  end

  private

  def self.get_search_response_from_amazon(content)
    res = nil
    begin
      res = Amazon::Ecs.item_search(content, {response_group: 'Images,Reviews,ItemAttributes'})
    rescue => ex
      JobLog.log_info ex
    end
    return res
  end

  def self.process(str)
    # Unescape the html, downcase the string
    CGI::unescapeHTML(str).downcase.gsub(/(\s|`)/) do |match|
      case match
      when /\s/; ''   # Remove all spaces
      when '`'; "'"   # Replace backticks with forward single quote
      end
    end
  end

# Changing the URL incase of https is more like a workaround. There is no official documentation as such, but took the call after going through the following urls
# https://drupal.org/node/1837856
# https://github.com/EFForg/https-everywhere/blob/master/src/chrome/content/rules/AmazonAWS.xml
  def get_book_cover_ssl_url(http_url)
    uri = URI(http_url)
    uri.host = BookListItemPresenterConstants::AMAZON_SSL_URL
    uri.scheme = "https"
    uri.to_s
  end

end