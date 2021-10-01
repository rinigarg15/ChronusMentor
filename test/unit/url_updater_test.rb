require_relative './../test_helper.rb'

class UrlUpdaterTest < ActiveSupport::TestCase

  def test_show_not_handle_text_columns
    text_columns_so_far_hash = YAML.load(IO.read(Rails.root.to_s + "/test/fixtures/files/url_updater/text_columns_so_far.yaml")).to_h
    assert_compare_hash(get_text_columns_hash, text_columns_so_far_hash)
  end

  private

  def get_text_columns_hash
    tables = ActiveRecord::Base.connection.execute("show tables;").to_a.flatten
    table_text_columns = {}
    tables.each do |table|
      columns = ActiveRecord::Base.connection.execute("desc #{table};").to_a
      table_text_columns[table] = []
      columns.each do |column|
        table_text_columns[table] << column[0] if column[1].match(/text/)
      end
    end
    return table_text_columns.reject{|_k, v| v.blank?}
  end

  def assert_compare_hash(current, existing)
    to_add = get_add_or_remove_hash(current, existing)
    to_remove = get_add_or_remove_hash(existing, current)
    message = "Newly added or removed text columns have to be handled as part of the url_updater.rb. If it is not needed to be handled please add/remove them in text_columns_so_far.yaml file"
    assert to_add.blank? && to_remove.blank? , "#{message}\n New Columns Added: #{to_add} \n Columns Removed: #{to_remove} \n"
  end

  def get_add_or_remove_hash(current_or_existing, existing_or_current, result_hash = {})
    current_or_existing.each do |k, v|
      if existing_or_current[k].blank?
        result_hash[k] = v
      else
        diff = current_or_existing[k] - existing_or_current[k]
        result_hash[k] = diff if diff.any?
      end
    end
    result_hash
  end
end
