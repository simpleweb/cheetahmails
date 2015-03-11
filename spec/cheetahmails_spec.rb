require 'Cheetahmails'
require 'redis'

RSpec.describe Cheetahmails do

  before(:each) do
    @redis = Redis.new(Cheetahmails.configuration.redis)
    @redis.del "cheetahmails_access_token"

    Cheetahmails.configure do |config|
      config.username = ENV["USERNAME"]
      config.password = ENV["PASSWORD"]
    end
  end

  context "#get_token" do
    context "when not authenticated" do

      it "fails and raises an exception" do
        Cheetahmails.configure do |config|
          config.username = "invalid"
          config.password = "invalid"
        end
        expect { token = Cheetahmails.get_token }.to raise_error("400 Bad Request")
      end

      context "authenticating" do
        context "when credentials are valid" do
          it "authenticating returns a token" do
            expect(Cheetahmails.get_token).to be_kind_of(String)
          end

          it "caches the token" do
            token = Cheetahmails.get_token
            expect(@redis.get("cheetahmails_access_token")).to eq(token)
            expect(@redis.ttl "cheetahmails_access_token").to be > 28700
          end
        end
      end
    end
  end

  context "#find_list_member" do
    context "with an email address that does not exist in cheetahmail" do
      it "responds with false" do
        exists = Cheetahmails.find_list_member(Time.now.to_f.to_s + "@simpleweb.co.uk")
        expect(exists).to eq(false)
      end
    end

    context "with a known email address" do
      it "responds with the row" do
        response = Cheetahmails.find_list_member("tom@simpleweb.co.uk")
        expect(response).to be_kind_of(Hash)
        expect(response).to include("id", "properties")
        expect(response["id"]).to be_kind_of(Integer)
      end

      context "with an invalid access token" do
        before do
          @redis.set "cheetahmails_access_token", "invalid token"
        end

        it "responds with the row" do
          response = Cheetahmails.find_list_member("tom@simpleweb.co.uk")
          expect(response).to be_kind_of(Hash)
          expect(response).to include("id", "properties")
          expect(response["id"]).to be_kind_of(Integer)
          # expect(Cheetahmails).to receive(:get_token).exactly(3).times
        end
      end
    end
  end

  context "#add_list_member" do
    context "with a valid view id" do
      it "succeeds and returns true" do
        data = {
          "first_name" => "Tom",
          "last_name" => "Holder",
          "email_address" => "tom@simpleweb.co.uk"
        }
        response = Cheetahmails.add_list_member ENV['VIEW_ID'], data
        expect(response).to eq(true)
      end
    end

    context "with an invalid view id" do
      it "succeeds and returns true" do
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
end




