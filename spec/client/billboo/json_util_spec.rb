require_relative '../../spec_helper'

describe Billbo::JsonUtil do
  include Billbo::JsonUtil

  describe 'parse_attributes' do
    let(:now) { Time.now }

    it 'parses time attributes' do
      _(parse_attributes(foo_at: now.to_s)[:foo_at]).
        must_be_kind_of Time
    end

    it 'parses date attributes' do
      _(parse_attributes(foo_on: now.to_s)[:foo_on]).
        must_be_kind_of Date
    end

    it 'handles nil' do
      _(parse_attributes(foo_on: nil)[:foo_on]).
        must_be_nil
    end

    it 'pass other attributes' do
      [1, 't', :x, true, false].each do |v|
        _(parse_attributes(foo: v)[:foo]).
          must_equal v
      end
    end

    it 'parses nested attributes' do
      _(parse_attributes(parent: [{foo_at: now.to_s}])[:parent][0][:foo_at]).
        must_be_kind_of Time
    end
  end
end
