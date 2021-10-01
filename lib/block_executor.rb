module BlockExecutor

  def self.iterate_fail_safe(iterable)
    iterate_method = iterable.respond_to?(:find_each) ? :find_each : :each
    iterable.send(iterate_method) do |item|
      begin
        @block_executor_parents ||= []
        @block_executor_parents << item
        iterable.is_a?(Hash) ? yield(*item) : yield(item)
      rescue => e
        parent_info = @block_executor_parents.map do |parent|
          parent.respond_to?(:id) ? "#{parent.class} - #{parent.id}" : "#{parent}"
        end
        Airbrake.notify("FailSafeLoop Error -> Objects: #{parent_info.join(', ')} | Error: #{e.message}")
      ensure
        @block_executor_parents.delete_at(-1)
      end
    end
  end

  def self.execute_without_mails
    initial_state = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = false
    yield
  ensure
    ActionMailer::Base.perform_deliveries = initial_state
  end
end