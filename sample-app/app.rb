require 'yaml'
require 'uri'
require 'net/http'

LOGGED_IN_IDS = []

class SampleApp < Sinatra::Base
  CONFIG = YAML.load(File.read(File.join(__dir__, 'config.yml'))).transform_keys(&:to_sym)

  enable :sessions

  helpers do
    def logged_in?
      LOGGED_IN_IDS.include?(session[:user_id])
    end
  end

  get "/refresh-jwt" do
    refresh_jwt
  end

  get "/" do
    @medications = {}
    erb :sample
  end

  get "/ddi" do
    @medications = {}
    erb :sample_ddi
  end

  get "/other" do
    erb :sample_other
  end

  post "/" do
    @name = @params['name']
    @medications = @params['medications']
    erb :sample
  end

  # Note: This is NOT a good way of doing a cookie based login. There's no session key
  # created or password or anything like that, and the information on who's logged in 
  # is stored IN MEMORY!!! The purpose here is to simulate cookie based authentication.
  # When our plugins use the refresh_url, it should be behind a an authentication scheme
  # like this. When running this app, you will notice that the medication search will
  # not work until you've clicked the login link.
  get "/login/:user_id" do
    session[:user_id] = @params[:user_id]
    LOGGED_IN_IDS << @params[:user_id]
    redirect back
  end

  get "/logout" do
    LOGGED_IN_IDS.delete(session[:user_id])
    redirect back
  end

  get "/protected-refresh-jwt" do
    if logged_in?
      refresh_jwt
    else
      "not logged in"
    end
  end
  
  def refresh_jwt
    uri = URI("#{CONFIG[:api_server]}/v1/tokens")
    req = Net::HTTP::Post.new(uri)
    # TTL is in hours by default, but if we add an 'm' to our value, we request a TTL
    # in minutes. The following will create a token that lasts 15 minutes.
    req.body = { ttl: '15m' }.to_json
    req['Content-Type'] = 'application/json'
    req['Authorization'] = CONFIG[:api_key]
    req['Cache-Control'] = 'no-cache'
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    res = http.request(req)
    # The response from our API comes back in JSON, with a single field: token. Here
    # we're passing that value back as the response from the server to our client-side
    # JavaScript code.
    JSON.parse(res.body)['token']
  end
end