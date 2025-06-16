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
