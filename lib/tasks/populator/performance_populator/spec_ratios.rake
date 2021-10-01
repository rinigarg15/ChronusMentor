namespace :groups_db do
  desc "Pull spec ratios from production"
  task :fetch_model_ratios => :environment do
    collect_ratio = CollectRatio.new
    spec_keys = collect_ratio.manager.traverse_order - CollectRatio::EXCLUDED_KEYS
    csv_data = [CollectRatio::RATIOS_HEADERS]
    default_growth_rate = 1.25

    spec_keys.each_with_index do |item, index|
      time_start = Time.now
      print "#{index + 1}. #{item}"
      node = collect_ratio.manager.nodes[item]
      parent = node["parent_key"] || node["parent"]
      child_klass = collect_ratio.manager.get_class(item)
      counts_ary = collect_ratio.get_counts_ary(parent, child_klass, item)
      counts_ary_size = counts_ary.size
      counts_ary_percentiles_hsh = {}
      counts_ary.uniq.sort.reverse.each { |cnt| counts_ary_percentiles_hsh[cnt] = (100*counts_ary.count(cnt)/counts_ary_size) }
      # max item atleast 1%
      counts_ary_percentiles_hsh[counts_ary_percentiles_hsh.first[0]] = [counts_ary_percentiles_hsh.first[1], 1].max
      # reject other minute items, less than 1%
      counts_ary_percentiles_hsh.reject! { |k, v| v == 0 }
      # add all remaining percentage to the last item
      min_item_percent = 100 - counts_ary_percentiles_hsh.values[0...-1].sum
      counts_ary_percentiles_hsh[counts_ary_percentiles_hsh.keys.last] = min_item_percent
      # apply default growth rate
      counts_ary_percentiles_hsh = Hash[counts_ary_percentiles_hsh.to_a.map{|p| [(p[0]*default_growth_rate).to_i, p[1]]}]

      puts " [#{(Time.now - time_start).round(0)}s]"
      csv_data << [item, parent, counts_ary_percentiles_hsh.map{|x| x.reverse.join(':')}.join('|')]
    end
    collect_ratio.write_to_csv(csv_data, CollectRatio::SPEC_RATIOS_FILE_NAME)
  end

  # FIX later
  #
  # #Note: Used to predict growth in production data in last 90 days
  # #Uses: bundle exec rake production_data:growth_predictor CURRENT_DAY_DATA=<CSV file path to current day data> 30_DAY_AGO_DATA=<CSV file path to 30 days ago data> 60_DAY_AGO_DATA=<CSV file path to 60 days ago data> 90_DAY_AGO_DATA=<CSV file path to 90 days ago data>
  # #All Production data has to be generated using bundle exec rake production_data:fetch_model_ratios
  # task :growth_predictor => :environment do

  #   current_day_data = (CSV.read ENV['CURRENT_DAY_DATA']) || raise('Provide CSV file path for current Day Data')
  #   thirty_day_ago_data = (CSV.read ENV['30_DAY_AGO_DATA']) || raise('Provide CSV file path for 30 Day ago Data')
  #   sixty_day_ago_data = (CSV.read ENV['60_DAY_AGO_DATA']) || raise('Provide CSV file path for 60 Day ago Data')
  #   ninety_day_ago_data = (CSV.read ENV['90_DAY_AGO_DATA']) || raise('Provide CSV file path for 90 Day ago Data')
    
  #   # required to remove header from csv file
  #   current_day_data.shift
  #   thirty_day_ago_data.shift
  #   sixty_day_ago_data.shift
  #   ninety_day_ago_data.shift
    
  #   collect_ratio = CollectRatio.new
  #   #computes growth in production data per month
  #   data_growth_this_month = collect_ratio.data_growth_per_month(thirty_day_ago_data, current_day_data)
  #   data_growth_last_month = collect_ratio.data_growth_per_month(sixty_day_ago_data, thirty_day_ago_data)
  #   data_growth_last_to_last_month = collect_ratio.data_growth_per_month(ninety_day_ago_data, sixty_day_ago_data)
  #   collect_ratio.write_to_csv(data_growth_this_month, "30daygrowth.csv")
  #   collect_ratio.write_to_csv(data_growth_last_month, "60daygrowth.csv")
  #   collect_ratio.write_to_csv(data_growth_last_to_last_month, "90daygrowth.csv")
  #   growth_data = [data_growth_this_month, data_growth_last_month, data_growth_last_to_last_month]
  #   avg_growth = collect_ratio.avg_growth_per_quarter(current_day_data, {default: false, growth_data: growth_data})

  #   # write predicted growth in csv file name avg_growth_this_quarter.csv
  #   collect_ratio.write_to_csv(avg_growth, CollectRatio::GROWTH_PREDICTOR_FILE_NAME)
  # end

  # task :default_growth_predictor => :environment do
  #   current_day_data = (CSV.read ENV['CURRENT_DAY_DATA']) || raise('Provide CSV file path for current Day Data')
  #   current_day_data.shift    
  #   collect_ratio = CollectRatio.new
  #   avg_growth = collect_ratio.avg_growth_per_quarter(current_day_data, {default: true})
  #   collect_ratio.write_to_csv(avg_growth, CollectRatio::GROWTH_PREDICTOR_FILE_NAME)
  # end
end

#Note to update spec_config.yaml
#Use: bundle exec rake performance_populator:update_spec GROWTH_DATA=<CSV file path to growth data> GROWTH_DATA=<CSV file tpath for growth data>
namespace :performance_populator do
  task :update_spec => :environment do
    csv1 = CSV.read ENV['GROWTH_DATA'] || raise('Provide CSV Path for growth Data')
    csv1.shift
    collect_ratio = CollectRatio.new
    collect_ratio.update_spec(csv1)
    collect_ratio.process_spec
    collect_ratio.write_to_yaml(collect_ratio.manager.nodes)
  end
end
