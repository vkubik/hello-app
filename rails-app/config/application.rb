require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module HelloWorldApp
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = false
  end
end
