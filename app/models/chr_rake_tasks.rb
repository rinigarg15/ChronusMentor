class ChrRakeTasks < ActiveRecord::Base
  #Possible rake task status
  module Status
    PENDING = 0 #Rake task ready to execute
    SUCCESS = 1 #Ran successfully
    FAILURE = 2 #Failed during running
  end

  validates_inclusion_of :status, :in => [Status::PENDING, Status::SUCCESS, Status::FAILURE]
end