require 'net/http'
require 'uri'

module CronMonitor
  class Signal
    API_PATH = "https://hc-ping.com/"

    attr_accessor :receiver

    def initialize(receiver)
      self.receiver = receiver
    end

    def trigger
      Net::HTTP.get(URI.parse(API_PATH + self.receiver))
    end
  end
end
