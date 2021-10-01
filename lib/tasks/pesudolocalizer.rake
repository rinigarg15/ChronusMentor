#!/usr/bin/env ruby
#encoding : utf-8
namespace :db do
  task :pseudolocalize => :environment do
  require 'yaml'
  target_file = "#{Rails.root.to_s}/tmp/phrase.all.yml"
  files = Dir.glob("./config/locales/**/*")
  overall_hash = {}
  files.each_with_index do |file_name, index|
    if file_name.end_with?('.yml') && ! file_name.match("phrase.[a-zA-Z]*[/-]*[a-zA-Z]*\.yml")
      hash = YAML.load(File.open(file_name))
      overall_hash.deep_merge!(hash)
    end
  end
  File.open(target_file, "w+") do |file|
    file.write overall_hash.to_yaml
  end
  pseudolocalization_target_file = "#{Rails.root.to_s}/config/locales/phrase.af.yml"
  Globalization::PseudolocalizeUtils.pseudolocalize_file(target_file,pseudolocalization_target_file)
  end
end