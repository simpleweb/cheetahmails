require 'Cheetahmails'
require 'redis'

RSpec.configure do |config|
  config.before(:each) do
    begin
      redis = Redis.new(Cheetahmails.configuration.redis)
      redis.del "cheetahmails_access_token"
    rescue => error
    end

    Cheetahmails.configure do |config|
      config.username = ENV['USERNAME']
      config.password = ENV['PASSWORD']
    end
  end
end

RSpec.describe Cheetahmails, "#get_token" do
  context "without being authenticated" do
    it "authenticating does not return a token when credentials are invalid" do
      Cheetahmails.configure do |config|
        config.username = "invalid"
        config.password = "invalid"
      end
      expect { token = Cheetahmails.get_token }.to raise_error("400 Bad Request")
   end
    it "authenticating returns a token when credentials are valid" do
      token = Cheetahmails.get_token
      expect(token).to be_kind_of(String)
    end
    it "authenticating caches a token to redis when credentials are valid" do
      token = Cheetahmails.get_token
      expect(token).to be_kind_of(String)

      begin
        redis = Redis.new(Cheetahmails.configuration.redis)
        cached_token = redis.get "cheetahmails_access_token"

        expect(cached_token).to eq(token)

        # Expiry on token
        expect(redis.ttl "cheetahmails_access_token").to be > 28700
      rescue => error
        expect(true).to eq(false)
      end

    end
  end
end

RSpec.describe Cheetahmails, "#find_list_member" do
  context "with a uniquely generated email address" do
    it "does not exist in cheetahmail" do
      exists = Cheetahmails.find_list_member(Time.now.to_f.to_s + "@simpleweb.co.uk")
      expect(exists).to eq(false)
    end
  end
  context "with a known email address" do
    it "does exist in cheetahmail" do
      exists = Cheetahmails.find_list_member("tom@simpleweb.co.uk")
      expect(exists["id"]).to be_kind_of(Integer)
    end
  end
  context "with an invalid access token and a known email address" do
    # This tests the re-generation of auth token
    it "does exist in cheetahmail" do

      begin
        redis = Redis.new(Cheetahmails.configuration.redis)
        redis.set "cheetahmails_access_token", "invalid token"
      rescue => error
        expect(true).to eq(false)
      end

      exists = Cheetahmails.find_list_member("tom@simpleweb.co.uk")
      expect(exists["id"]).to be_kind_of(Integer)
    end
  end
end

RSpec.describe Cheetahmails, "#add_list_member" do
  context "with a valid view id" do
    it "is possible to add a customer" do
      data = {
        "first_name" => "Tom",
        "last_name" => "Holder",
        "email_address" => "tom@simpleweb.co.uk"
      }
      response = Cheetahmails.add_list_member ENV['VIEW_ID'], data
      expect(response).to eq(true)
    end
  end
  context "without a valid view id" do
    it "is not possible to add a customer" do
      data = {
        "first_name" => "Tom",
        "last_name" => "Holder",
        "email_address" => "tom@simpleweb.co.uk"
      }
      response = Cheetahmails.add_list_member -9999, data
      expect(response).to eq(false)
    end
  end
end
