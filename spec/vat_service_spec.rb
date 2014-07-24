require 'spec_helper'

describe VatService do

  let(:service) { VatService.new }

  describe '#calculate' do
    it 'calculates correct VAT amount' do
      example(100, 'US', true).must_equal(0)
      example(100, 'US', false).must_equal(0)

      example(100, 'FR', true).must_equal(0)
      example(100, 'FR', false).must_equal(21)

      example(100, 'BE', false).must_equal(21)
      example(100, 'BE', true).must_equal(21)
    end
  end

  def example amount, country_code, company
    service.calculate(
      amount: amount, country_code: country_code, is_company: company)
  end
end
