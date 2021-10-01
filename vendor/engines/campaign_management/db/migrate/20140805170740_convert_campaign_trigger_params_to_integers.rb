class ConvertCampaignTriggerParamsToIntegers < ActiveRecord::Migration[4.2]

  def change
    CampaignManagement::AbstractCampaign.all.each do |c|
      next if c.trigger_params.nil?
      old_hash = c.trigger_params
      result = old_hash.map do |k,v|
        [k, v.map{|y| y.to_i}]
      end
      c.trigger_params = Hash[result]
      c.save!
    end
  end
end
