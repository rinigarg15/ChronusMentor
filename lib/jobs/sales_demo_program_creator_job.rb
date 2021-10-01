class SalesDemoProgramCreatorJob < Struct.new(:options)
  def perform
    SalesDemo::SalesPopulator.new(options).populate
  end

  def max_attempts
    1
  end
end