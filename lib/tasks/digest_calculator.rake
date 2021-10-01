namespace :digest_calculator do
  desc "Calculates the overall digest & stores it in data_digest.yml file "
  task :overall_digest => [:environment] do
    DigestCalculator.compute_overall_digest
  end

  desc "Calculate digest for ES indexes versions"
  task :es_indexes_digest => [:environment] do
    DigestCalculator.compute_es_indexes_digest_of_versions
  end
end