module ImportExportUtils

  def extract_data_rows_from_csv_data(obj, data, item_to_data_module_mapper, items_header)
    items_header.each do |item|
      obj.instance_variable_set("@#{item}_rows", extract_item_rows(data, item_to_data_module_mapper[item]::BLOCK_IDENTIFIER))
    end
  end

  def extract_item_rows(data, item_identifier)
    block_begin_index = data.index{|row| row[0].eql?(item_identifier)}
    if block_begin_index.present?
      first_index = block_begin_index + 2

      last_index = first_index + (data[first_index..-1].index{|row| is_empty(row)} || data.size) - 1
      data[first_index..last_index]
    else
      []
    end
  end

  def self.get_temp_file(file_or_url)
    downloaded_file = open(file_or_url)
    #For filesize less than 10KB, open returns a stringIO, which needs to be converted to a file.
    if downloaded_file.is_a?(StringIO)
      tempfile = Tempfile.new("open-uri", binmode: true)
      IO.copy_stream(downloaded_file, tempfile.path)
      downloaded_file = tempfile
    end
    return downloaded_file
  rescue => e
    Airbrake.notify(e)
  end

  def self.copy_image(destination, source)
    img = Magick::Image.read(source).first
    img.write destination
  end

  def is_empty(row)
    row.reject{|x| x.nil?}.count.zero?
  end

  def self.file_url(file_path)
    if file_path =~ /http(s?):\/\//
      file_path
    elsif file_path =~ /assets/
      Rails.root.to_s + "/app" + file_path.gsub(/\?[\d]+/, "").gsub(/assets/, "assets/images")
    else
      Rails.root.to_s + "/public" + file_path.gsub(/\?[\d]+/, "")
    end
  end
end