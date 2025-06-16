class MetricsController < ApplicationController
  def index
    render plain: Yabeda::Prometheus.registry.to_s, content_type: 'text/plain'
  end
end
