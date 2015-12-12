# You should edit this file with the browsers you wish to use
# For options, check out http://saucelabs.com/docs/platforms
if ENV['USE_SAUCE']
  require 'sauce'
  require 'sauce/capybara'
  Capybara.default_driver    = :sauce
  Capybara.javascript_driver = :sauce
  Capybara.run_server        = false
end

Sauce.config do |config|
  config[:start_local_application] = ENV['USE_SAUCE']
  config[:start_tunnel]            = ENV['USE_SAUCE']

  if ENV.fetch('CIRCLE_TEST_REPORTS', nil).blank?
    # not running on CircleCI, assume local run
    config[:sauce_connect_4_executable] = "#{$HOME}/bin/sc"
  end

  config[:browsers]                = [
    #['Windows 8','Internet Explorer','10'],
    #['Windows 8.1','Internet Explorer','11'],
    #['Windows 7','Internet Explorer','9'],
    #['Windows 7','Internet Explorer','10'],
    #['Windows 7','Internet Explorer','11'],
    ['Windows 10','Internet Explorer','11'],
    #['Windows 8','Firefox','40'],
    #['Windows 8','Chrome','46'],
    #['Linux','Chrome','46'],
    #['Linux','Firefox','40'],
    #['OS X 10.10','Firefox','40'],
    #['OS X 10.10','Chrome','46'],
    #['OS X 10.9','Safari','7'],
    #['OS X 10.10','Safari','8'],
    #['OS X 10.11','Safari','9']
  ]
end
