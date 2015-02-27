require 'Cheetahmails'
require 'redis'

RSpec.configure do |config|
  config.before(:each) do
    redis = Redis.new(Cheetahmails.configuration.redis)
    redis.del "cheetahmails_access_token"
    Cheetahmails.configure do |config|
      config.username = ENV['USERNAME']
      config.password = ENV['PASSWORD']
    end
  end
end

RSpec.describe Cheetahmails, "#getToken" do
  context "without being authenticated" do
    it "authenticating does not return a token when credentials are invalid" do
      Cheetahmails.configure do |config|
        config.username = "invalid"
        config.password = "invalid"
      end
      expect { token = Cheetahmails.getToken }.to raise_error("400 Bad Request")
   end
    it "authenticating returns a token when credentials are valid" do
      token = Cheetahmails.getToken
      expect(token).to be_kind_of(String)
    end
    it "authenticating caches a token to redis when credentials are valid" do
      token = Cheetahmails.getToken
      expect(token).to be_kind_of(String)

      redis = Redis.new(Cheetahmails.configuration.redis)
      cached_token = redis.get "cheetahmails_access_token"

      expect(cached_token).to eq(token)

      # Expiry on token
      expect(redis.ttl "cheetahmails_access_token").to be > 28700
    end
  end
end

RSpec.describe Cheetahmails, "#customerExists" do
  context "with a uniquely generated email address" do
    it "does not exist in cheetahmail" do
      exists = Cheetahmails.customerExists(Time.now.to_f.to_s + "@simpleweb.co.uk")
      expect(exists).to eq(false)
    end
  end
  context "with a known email address" do
    it "does exist in cheetahmail" do
      exists = Cheetahmails.customerExists("tom@simpleweb.co.uk")
      expect(exists).to be_kind_of(Integer)
    end
  end
  context "with an invalid access token and a known email address" do
    # This tests the re-generation of auth token
    it "does exist in cheetahmail" do

      redis = Redis.new(Cheetahmails.configuration.redis)
      redis.set "cheetahmails_access_token", "invalid token"

      exists = Cheetahmails.customerExists("tom@simpleweb.co.uk")
      expect(exists).to be_kind_of(Integer)
    end
  end
end

RSpec.describe Cheetahmails, "#addCustomer" do
  context "with a valid view id" do
    it "is possible to add a customer" do
      data = {
        "first_name" => "Tom",
        "last_name" => "Holder",
        "email_address" => "tom@simpleweb.co.uk"
      }
      response = Cheetahmails.addCustomer ENV['VIEW_ID'], data
      expect(response).to eq(true)
    end
  end
end
