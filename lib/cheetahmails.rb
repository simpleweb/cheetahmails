require 'httparty'
require 'json'
require 'redis'

module Cheetahmails
  include HTTParty
  base_uri 'https://login.eccmp.com'

  class << self
    attr_accessor :configuration
  end

  def self.getToken(clear_cache = false)
    tries ||= 2

    redis = Redis.new(Cheetahmails.configuration.redis)

    redis.del "cheetahmails_access_token" if clear_cache

    if not token = redis.get("cheetahmails_access_token")

      @options = {
        headers: {"Content-Type" => "application/x-www-form-urlencoded"},
        body: {
          "username" => Cheetahmails.configuration.username,
          "password" => Cheetahmails.configuration.password,
          "grant_type" => "password"
        }
      }

      response = self.post('/services2/authorization/oAuth2/Token', @options)

      raise RetryException, response.code.to_s + " " + response.body if response.code != 200

      begin
        jsonresponse = JSON.parse(response.body)
      rescue JSON::ParserError => error
        raise response.code.to_s + " " + response.body
      end

      if token = jsonresponse["access_token"]
        redis.set("cheetahmails_access_token", token)
        redis.expire("cheetahmails_access_token", jsonresponse["expires_in"])
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

  def self.customerExists(email)
    tries ||= 2

    @options = {
      headers: {
        "Authorization" => "Bearer " + self.getToken(tries < 2),
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      },
      query: {
        "viewName" => Cheetahmails.configuration.view_name,
        "prop" => '', #first_name,last_name
        "columnName" => "email_address",
        "operation" => "=",
        "param" => email
      }
    }

    response = self.get('/services2/api/SearchRecords', @options)

    begin
      jsonresponse = JSON.parse(response.body)
    rescue JSON::ParserError => error
      return nil
    end

    raise RetryException, jsonresponse["message"] if response.code == 401

    begin
      id = jsonresponse[0]["id"]
    rescue => error
      return false
    end

  rescue RetryException => e
    if (tries -= 1) > 0
      retry
    end
  end

  def self.addCustomer(api_post_id, key_data)
    tries ||= 2

    data = []

    key_data.each do |key, value|
      data << { "name" => key, "value" => value}
    end

    data = {"apiPostId" => api_post_id, "data" => data}

    @options = {
      headers: {
        "Authorization" => "Bearer " + self.getToken(tries < 2),
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      },
      body: data.to_json
    }

    response = self.post('/services2/api/Recipients', @options)

    begin
      jsonresponse = JSON.parse(response.body)
    rescue JSON::ParserError => error
      return nil
    end

    raise RetryException, jsonresponse["message"] if response.code == 401

    return response.code == 200 && jsonresponse["success"]

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
