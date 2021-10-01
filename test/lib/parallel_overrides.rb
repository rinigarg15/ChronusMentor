# If we upgrade Parallel gem, we might have to update this
# 
# Include this overrides file ONLY IN TESTS 
require 'minitest'
require 'mocha/setup'
module Parallel
  def self.each(array, options={}, &block)
    array = prepare(array)
    array.each do |item|
      yield item
    end
  end

  def self.each_with_index(array, options={}, &block)
    array = prepare(array)
    array.each_with_index do |item, index|
      yield item, index
    end
  end

  def self.map(array, options = {}, &block)
    array = prepare(array)
    result_array = []
    array.each do |item|
      result_item = yield(item)
      result_array << result_item
    end
    result_array
  end

  def self.map_with_index(array, options={}, &block)    
    array = prepare(array)
    result_array = []
    array.each_with_index do |item, index|
      result_item = yield item, index
      result_array << result_item
    end
    result_array
  end

  private

  def self.prepare(array)
    ActiveRecord::Base.connection.stubs(:reconnect!)
    array.to_a
  end
end