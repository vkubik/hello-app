require 'yabeda'
require 'yabeda/rails'
require 'yabeda/prometheus'

Yabeda.configure do
  group :rails_app do
    counter :requests_total, comment: "Total number of HTTP requests"
    histogram :request_duration, comment: "HTTP request duration"
    gauge :active_connections, comment: "Number of active connections"
  end
end

Yabeda.configure!
