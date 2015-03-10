require 'faraday'
require 'json'
require 'redis'

module Cheetahmails
  @base_uri = 'https://login.eccmp.com'

  class << self
    attr_accessor :configuration
  end

  def self.get_token(clear_cache = false)
    tries ||= 2

    begin
      redis = Redis.new(Cheetahmails.configuration.redis)
      redis.del "cheetahmails_access_token" if clear_cache
      token = redis.get("cheetahmails_access_token")
    rescue => error
    end

    if not token

      faraday = Faraday.new(:url => @base_uri) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        #faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      params = {
        "username" => Cheetahmails.configuration.username,
        "password" => Cheetahmails.configuration.password,
        "grant_type" => "password"
      }

      response = faraday.post '/services2/authorization/oAuth2/Token', params

      raise RetryException, response.status.to_s + " " + response.body if response.status != 200

      begin
        jsonresponse = JSON.parse(response.body)
      rescue JSON::ParserError => error
        raise response.status.to_s + " " + response.body
      end

      if token = jsonresponse["access_token"]
        begin
          redis.set("cheetahmails_access_token", token)
          redis.expire("cheetahmails_access_token", jsonresponse["expires_in"])
        rescue => error
        end
      end

    end

    token

  rescue RetryException => e
    if (tries -= 1) > 0
      retry
    else
      raise e
    end
  end

  def self.find_list_member(email, prop='')
    tries ||= 2

    faraday = Faraday.new(:url => @base_uri) do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      #faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    faraday.headers["Authorization"] = "Bearer " + self.get_token(tries < 2)
    faraday.headers["Content-Type"] = "application/json"
    faraday.headers["Accept"] = "application/json"

    params = {
      "viewName" => Cheetahmails.configuration.view_name,
      "prop" => prop, #first_name,last_name
      "columnName" => "email_address",
      "operation" => "=",
      "param" => email
    }

    response = faraday.get '/services2/api/SearchRecords', params

    begin
      jsonresponse = JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise response.statzus.to_s + " " + response.body
    end

    raise RetryException, jsonresponse["message"] if response.status == 401

    return false if response.status == 404

    begin
      return jsonresponse[0]
    rescue => error
      return false
    end

  rescue RetryException => e
    if (tries -= 1) > 0
      retry
    end
  end

  def self.add_list_member(api_post_id, key_data)
    tries ||= 2

    data = []

    key_data.each do |key, value|
      data << { "name" => key, "value" => value}
    end

    data = {"apiPostId" => api_post_id, "data" => data}

    faraday = Faraday.new(:url => @base_uri) do |faraday|
      #faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    response = faraday.post do |req|
      req.url '/services2/api/Recipients'
      req.headers["Authorization"] = "Bearer " + self.get_token(tries < 2)
      req.headers["Content-Type"] = "application/json"
      req.headers["Accept"] = "application/json"
      req.body = data.to_json
    end

    begin
      jsonresponse = JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise response.status.to_s + " " + response.body
    end

    raise RetryException, jsonresponse["message"] if response.status == 401

    return response.status == 200 && jsonresponse["success"]

  rescue RetryException => e
    if (tries -= 1) > 0
      retry
    end
  end

  def self.configuration
    @configuration ||=  Configuration.new
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :username
    attr_accessor :password
    attr_accessor :redis
    attr_accessor :view_name

    def initialize
      @username = ''
      @password = ''
      @view_name = 'Email Recipient'
      @redis = { :host => "127.0.0.1", :port => 6379, :db => 0 }
    end
  end

  class RetryException < RuntimeError
  end

end
