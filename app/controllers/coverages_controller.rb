class CoveragesController < ApplicationController

    # see config/environments/standby.rb
    def get_coverage
      if ENV['RAILS_ENV']=="standby" || ENV['RAILS_ENV']=="development"
        SimpleCov.result.format!
        render plain: "Wrote results. STOP AND RESTART THE SERVER TO BEGIN A NEW COVERAGE RUN!!"
      end
    end
end
