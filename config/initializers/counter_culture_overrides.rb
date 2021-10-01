CounterCulture::Extensions.module_eval do
  private

  def _update_counts_after_destroy
    # If create and update are performed in the same transaction, '@_counter_culture_active = true' ensures that the counter is incremented only once.
    # But if destroy also happens in that transaction, then @_counter_culture_active should be reset to false.
    @_counter_culture_active = false

    _wrap_in_counter_culture_active do
      self.class.after_commit_counter_cache.each do |counter|
        # decrement counter cache
        counter.change_counter_cache(self, increment: false)
      end
    end
  end
end