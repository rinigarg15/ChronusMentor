module CronMonitor
  class Signal
    API_PATH = 'https://hchk.io/'

    attr_accessor :receiver

    def initialize(receiver)
      self.receiver = receiver
    end

    def trigger(options = {})
      Net::HTTP.get(URI.parse(API_PATH + self.receiver))
    end
  end
end