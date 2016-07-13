require_relative '../../spec_helper'

describe Billbo::JsonUtil do
  include Billbo::JsonUtil

  describe 'parse_attributes' do
    let(:now) { Time.now }

    it 'parses time attributes' do
      parse_attributes(foo_at: now.to_s)[:foo_at].
        must_be_kind_of Time
    end

    it 'parses date attributes' do
      parse_attributes(foo_on: now.to_s)[:foo_on].
        must_be_kind_of Date
    end

    it 'pass other attributes' do
      [1, 't', :x, true, false].each do |v|
        parse_attributes(foo: v)[:foo].
          must_equal v
      end
    end

    it 'parses nested attributes' do
      parse_attributes(parent: [{foo_at: now.to_s}])[:parent][0][:foo_at].
        must_be_kind_of Time
    end
  end
end
