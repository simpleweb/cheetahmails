Gem::Specification.new do |s|
  s.name        = 'cheetahmails'
  s.version     = '0.0.1'
  s.date        = '2015-02-22'
  s.summary     = "Cheetah mail is a clunky campaign manager by Experian"
  s.description = "Some basic cheetah mail API end points implemented"
  s.authors     = ["Tom Holder"]
  s.email       = 'tom@simpleweb.co.uk'
  s.files       = Dir["{lib}/**/*", "Gemfile"]
  s.homepage    =
    'http://rubygems.org/gems/cheetahmail'
  s.license       = 'MIT'
  s.add_dependency "faraday",["~> 0.9.1"]
  s.add_dependency "redis", ["~> 3.0.1"]

  s.add_development_dependency "rspec"
  s.add_development_dependency 'dotenv'
end
