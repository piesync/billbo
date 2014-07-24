class App < Sinatra::Base

  get '/ping' do
    status 200
  end
end
