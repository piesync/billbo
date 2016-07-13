module Billbo
  module JsonUtil
    def parse_attributes(data)
      case data
      when Hash
        data.map do |(k,v)|
          {
            k => v && case k.to_s
                      when /_at$/
                        Time.parse(v)
                      when /_on$/
                        Date.parse(v)
                      else
                        parse_attributes(v)
                      end
          }
        end.reduce(&:merge!)
      when Array
        data.map{|v| parse_attributes(v)}
      else
        data
      end
    end
    module_function :parse_attributes
  end
end
