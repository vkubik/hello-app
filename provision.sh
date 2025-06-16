#!/bin/bash

set -e

echo "Starting Technical Test Environment Provisioning..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Create directory structure
create_structure() {
    print_status "Creating directory structure..."
    
    mkdir -p rails-app/config/initializers
    mkdir -p rails-app/app/controllers
    mkdir -p rails-app/app/views/home
    mkdir -p monitoring/prometheus
    mkdir -p monitoring/grafana/provisioning/datasources
    mkdir -p monitoring/grafana/provisioning/dashboards
    mkdir -p monitoring/grafana/dashboards
    mkdir -p monitoring/alertmanager
    mkdir -p docs
    
    print_status "Directory structure created ✓"
}

# Generate Rails application files
generate_rails_app() {
    print_status "Generating Rails application files..."
    
    # Gemfile
    cat > rails-app/Gemfile << 'EOF'
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.0'

gem 'rails', '~> 7.0.0'
gem 'pg', '~> 1.1'
gem 'redis', '~> 4.0'
gem 'puma', '~> 5.0'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'prometheus-client'
gem 'yabeda-rails'
gem 'yabeda-prometheus'
gem 'yabeda-puma-plugin'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end
EOF

    # Dockerfile
    cat > rails-app/Dockerfile << 'EOF'
FROM ruby:3.1.0-alpine

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    yarn

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
EOF

    # Config files
    cat > rails-app/config/application.rb << 'EOF'
require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module HelloWorldApp
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = false
  end
end
EOF

    cat > rails-app/config/boot.rb << 'EOF'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
EOF

    cat > rails-app/config/environment.rb << 'EOF'
require_relative "application"
Rails.application.initialize!
EOF

    # Database configuration
    cat > rails-app/config/database.yml << 'EOF'
default: &default
  adapter: postgresql
  encoding: unicode
  host: postgres
  username: postgres
  password: password
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: hello_world_development

production:
  <<: *default
  database: hello_world_production
EOF

    # Redis configuration
    cat > rails-app/config/initializers/redis.rb << 'EOF'
require 'redis'

$redis = Redis.new(host: 'redis', port: 6379, db: 0)
EOF

    # Metrics configuration
    cat > rails-app/config/initializers/metrics.rb << 'EOF'
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
EOF

    # Routes
    cat > rails-app/config/routes.rb << 'EOF'
Rails.application.routes.draw do
  root 'home#index'
  get '/health', to: 'home#health'
  get '/metrics', to: 'metrics#index'
end
EOF

    # Controllers
    cat > rails-app/app/controllers/application_controller.rb << 'EOF'
class ApplicationController < ActionController::Base
end
EOF

    cat > rails-app/app/controllers/home_controller.rb << 'EOF'
class HomeController < ApplicationController
  def index
    @message = "Hello World from Rails with SRE Monitoring!"
    @redis_status = check_redis
    @db_status = check_database
  end

  def health
    status = {
      status: 'ok',
      timestamp: Time.current,
      services: {
        database: check_database,
        redis: check_redis
      }
    }
    render json: status
  end

  private

  def check_redis
    $redis.ping == 'PONG' ? 'connected' : 'disconnected'
  rescue
    'disconnected'
  end

  def check_database
    ActiveRecord::Base.connection.active? ? 'connected' : 'disconnected'
  rescue
    'disconnected'
  end
end
EOF

    cat > rails-app/app/controllers/metrics_controller.rb << 'EOF'
class MetricsController < ApplicationController
  def index
    render plain: Yabeda::Prometheus.registry.to_s, content_type: 'text/plain'
  end
end
EOF

    # Views
    cat > rails-app/app/views/home/index.html.erb << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Hello World - SRE Test</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
    .connected { background-color: #d4edda; color: #155724; }
    .disconnected { background-color: #f8d7da; color: #721c24; }
  </style>
</head>
<body>
  <h1><%= @message %></h1>
  
  <h2>Service Status</h2>
  <div class="status <%= @db_status == 'connected' ? 'connected' : 'disconnected' %>">
    Database: <%= @db_status %>
  </div>
  <div class="status <%= @redis_status == 'connected' ? 'connected' : 'disconnected' %>">
    Redis: <%= @redis_status %>
  </div>
  
  <h2>Monitoring Links</h2>
  <ul>
    <li><a href="http://localhost:3001" target="_blank">Grafana Dashboard</a></li>
    <li><a href="http://localhost:9090" target="_blank">Prometheus</a></li>
    <li><a href="http://localhost:9093" target="_blank">Alertmanager</a></li>
    <li><a href="/metrics" target="_blank">Application Metrics</a></li>
    <li><a href="/health" target="_blank">Health Check</a></li>
  </ul>
</body>
</html>
EOF

    # Create empty Gemfile.lock
    touch rails-app/Gemfile.lock

    print_status "Rails application files generated ✓"
}

# Generate monitoring configuration
generate_monitoring_config() {
    print_status "Generating monitoring configuration..."
    
    # Prometheus configuration
    cat > monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'rails-app'
    static_configs:
      - targets: ['rails-app:3000']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

    # Alert rules
    cat > monitoring/prometheus/alert_rules.yml << 'EOF'
groups:
  - name: application_alerts
    rules:
      - alert: ApplicationDown
        expr: up{job="rails-app"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Rails application is down"
          description: "The Rails application has been down for more than 30 seconds"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(rails_app_request_duration_bucket[5m])) > 0.5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is above 500ms"

      - alert: HighErrorRate
        expr: rate(rails_app_requests_total{status=~"5.."}[5m]) / rate(rails_app_requests_total[5m]) > 0.1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 10%"

  - name: database_alerts
    rules:
      - alert: PostgreSQLDown
        expr: up{job="postgres"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down"
          description: "PostgreSQL has been down for more than 30 seconds"

      - alert: PostgreSQLHighConnections
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL high connection usage"
          description: "PostgreSQL is using more than 80% of available connections"

  - name: redis_alerts
    rules:
      - alert: RedisDown
        expr: up{job="redis"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Redis is down"
          description: "Redis has been down for more than 30 seconds"

      - alert: RedisHighMemoryUsage
        expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Redis high memory usage"
          description: "Redis memory usage is above 90%"

  - name: system_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80%"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 90%"
EOF

    # Alertmanager configuration
    cat > monitoring/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@example.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true
EOF

    # Grafana datasource
    cat > monitoring/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Grafana dashboard provisioning
    cat > monitoring/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    print_status "Monitoring configuration generated ✓"
}

# Generate Docker Compose file
generate_docker_compose() {
    print_status "Generating Docker Compose configuration..."
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Application Services
  rails-app:
    build: ./rails-app
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=development
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/hello_world_development
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - postgres
      - redis
    volumes:
      - ./rails-app:/app
    command: >
      sh -c "bundle install &&
             bundle exec rails db:create db:migrate &&
             bundle exec rails server -b 0.0.0.0"

  postgres:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: hello_world_development
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  # Monitoring Services
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
      - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards
      - grafana_data:/var/lib/grafana

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager:/etc/alertmanager
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'

  # Exporters
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:password@postgres:5432/hello_world_development?sslmode=disable"
    ports:
      - "9187:9187"
    depends_on:
      - postgres

  redis-exporter:
    image: oliver006/redis_exporter:latest
    environment:
      REDIS_ADDR: "redis://redis:6379"
    ports:
      - "9121:9121"
    depends_on:
      - redis

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:
  alertmanager_data:
EOF

    print_status "Docker Compose configuration generated ✓"
}

# Generate documentation
generate_documentation() {
    print_status "Generating documentation..."
    
    cat > docs/metrics.md << 'EOF'
# Metrics and Monitoring Guide

## Key Metrics to Watch

### Application Metrics (Rails)
- **up{job="rails-app"}**: Service availability (0 or 1)
- **rails_app_requests_total**: Total number of HTTP requests
- **rails_app_request_duration**: HTTP request duration histogram

### Database Metrics (PostgreSQL)
- **up{job="postgres"}**: Database availability
- **pg_stat_database_numbackends**: Number of active connections
- **pg_settings_max_connections**: Maximum allowed connections

### Cache Metrics (Redis)
- **up{job="redis"}**: Redis availability
- **redis_memory_used_bytes**: Memory used by Redis
- **redis_connected_clients**: Number of connected clients

### System Metrics
- **node_cpu_seconds_total**: CPU usage
- **node_memory_MemAvailable_bytes**: Available memory
- **node_filesystem_avail_bytes**: Available disk space

## Alerting Rules

### Critical Alerts
- Service down for > 30 seconds
- Error rate > 10% for > 1 minute
- Disk space < 10%

### Warning Alerts
- Response time > 500ms for > 2 minutes
- High resource usage (CPU > 80%, Memory > 90%)
- High connection count
EOF

    print_status "Documentation generated ✓"
}

# Start services
start_services() {
    print_status "Starting services with Docker Compose..."
    
    # Stop any existing services
    docker-compose down -v 2>/dev/null || true
    
    # Build and start services
    docker-compose up -d --build
    
    print_status "Services started ✓"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for Rails app
    print_status "Checking Rails application..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
            print_status "Rails application is ready ✓"
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    
    if [ $timeout -le 0 ]; then
        print_warning "Rails application may still be starting. Check 'docker-compose logs rails-app'"
    fi
    
    print_status "All services should be ready ✓"
}

# Display final information
display_info() {
    print_status "Environment provisioning completed successfully! 🎉"
    echo
    echo "📊 Access your services:"
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ Rails App:    http://localhost:3000                    │"
    echo "│ Grafana:      http://localhost:3001 (admin/admin)      │"
    echo "│ Prometheus:   http://localhost:9090                    │"
    echo "│ Alertmanager: http://localhost:9093                    │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo
    echo "🔧 Management commands:"
    echo "  Stop services:    docker-compose down"
    echo "  View logs:        docker-compose logs -f [service_name]"
    echo "  Restart service:  docker-compose restart [service_name]"
    echo
}

# Cleanup function
cleanup_on_error() {
    print_error "An error occurred. Check the logs above for details."
    print_warning "You can clean up with: docker-compose down -v"
    exit 1
}

# Set trap for cleanup on error
trap cleanup_on_error ERR

# Main execution
main() {
    print_status "Starting Technical Test Environment Setup"
    
    check_prerequisites
    create_structure
    generate_rails_app
    generate_monitoring_config
    generate_docker_compose
    generate_documentation
    start_services
    wait_for_services
    display_info
}

# Execute main function
main "$@"
