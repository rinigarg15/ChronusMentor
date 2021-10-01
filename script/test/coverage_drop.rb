require 'smarter_csv'

old_coverage_array = SmarterCSV.process(ARGV[0])
old_coverage_hash = {}
old_coverage_array.collect { |row| old_coverage_hash[row[:file]] = row[:"%_covered"] }

new_coverage_array = SmarterCSV.process(ARGV[1])
new_coverage_array.each do |row|
  if old_coverage_hash[row[:file]].nil?
    puts "#{row[:file]} #{row[:'%_covered']} NEW FILE" if row[:'%_covered'].to_i < 99
  else
    puts "#{row[:file]} #{row[:'%_covered']} #{old_coverage_hash[row[:file]]}"  if row[:"%_covered"].to_i + 1 < old_coverage_hash[row[:file]].to_i
  end
end