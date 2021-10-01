class AddLinkedinUnlessPresent< ActiveRecord::Migration[4.2]
  def up
    if Feature.count > 0
      Feature.create_default_features
    end   
  end
end