ImpactDialing::Application.configure do
  TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  TWILIO_APP_SID="APb77a41681f20d46a1b37498ccb709092"
  APP_NUMBER="4157020991"
  HOST = APP_HOST = "admin.impactdialing.com"
  PORT = 80
  TEST_CALLER_NUMBER="8583679749"
  TEST_VOTER_NUMBER="4154486970"
  PUSHER_APP_ID="6964"
  PUSHER_KEY="6f37f3288a3762e60f94"
  PUSHER_SECRET="b9a1cfc2c1ab4b64ad03"

  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = true

  # See everything in the log (default is :info)
  config.log_level = :debug

  config.active_support.deprecation = :log

  config.after_initialize do
    ActiveMerchant::Billing::LinkpointGateway.pem_file  = File.read(Rails.root.join('1383715.pem'))
    ::BILLING_GW = gateway = ActiveMerchant::Billing::LinkpointGateway.new(
      :login => "1383715"
    )
  end
end
