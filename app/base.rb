class Base < Sinatra::Base

  def json
    @json ||= MultiJson.load(request.body.read, symbolize_keys: true)
  end
end
