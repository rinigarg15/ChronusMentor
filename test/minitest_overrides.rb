# 'startup' and 'shutdown' methods are class-level equivalents of 'setup' and 'teardown' methods.
# 'startup' and 'shutdown' methods can be used for initializing and uninitializing custom class definitions.

Minitest::Test.class_eval do
  def self.runnable_methods
    methods = methods_matching(/^test_/)

    case self.test_order
    when :random, :parallel then
      max = methods.size
      methods = methods.sort.sort_by { rand max }
    when :alpha, :sorted then
      methods = methods.sort
    else
      raise "Unknown test_order: #{self.test_order.inspect}"
    end
    methods_matching(/^startup$/) + methods + methods_matching(/^shutdown$/)
  end

  def result_code
    self.failure and self.failure.result_code or (self.name =~ /^test_/ ? "." : "")
  end
end