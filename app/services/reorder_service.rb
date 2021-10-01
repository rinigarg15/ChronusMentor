class ReorderService
  def initialize(objects)
    @objects_hash = objects.group_by(&:id)
  end

  def reorder(new_order, base_position = 0)
    ActiveRecord::Base.transaction do
      new_order.collect(&:to_i).each_with_index do |id, index|
        object = @objects_hash[id].first
        object.update_column(:position, index + base_position + 1)
      end
    end
  end
end