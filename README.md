Cheetah Mail is a mailing campaign manager by Experian.

This very simple gem was built to do two things:

1) Check if customers exist on a list (table)
2) Subscribe customers to a list (table)

The library implements their attempt at OAuth(!) and uses Redis to cache the access_token.

To use the gem you must configure it like:

    Cheetahmails.configure do |config|
      config.username = ENV['USERNAME']
      config.password = ENV['PASSWORD']
    end

To run the tests, create a .test.env file in the root of the project like:

    USERNAME=<YOUR_API_USERNAME>
    PASSWORD=<YOUR_API_PASSWORD>
    VIEW_ID=<YOUR_VIEW_ID>
