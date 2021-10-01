class ChronusAbExperiment
  attr_accessor :alternative, :running

  cattr_accessor :only_use_cookie
  self.only_use_cookie = false
  
  class << self
    def title
      "ChronusAbExperiment"
    end

    def experiment_config
      {}
    end

    def control_alternative
    end

    def split_config
      { self.title => self.experiment_config }
    end
  end

  def initialize(alternative=nil)
    if alternative.present?
      self.alternative = alternative
      self.running = true
    else
      self.alternative = self.class.control_alternative
      self.running = false
    end
  end

  def running? # To check if the test is running
    self.running
  end
end
