class ChronusAbTestSplitUser
  include Split::Helper

  def initialize(context)
    @context = context
  end

  def alternative_choosen(experiment_title)
    begin
      ab_user[experiment_title]
    # Errno::ECONNREFUSED, Redis::BaseError, SocketError, etc exceptions can happen due to redis unavailability
    rescue => e
      Airbrake.notify(e)
      return nil
    end
  end

  private

  def ab_user
    @ab_user ||= Split::User.new(@context)
  end
end