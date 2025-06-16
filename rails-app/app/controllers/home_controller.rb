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
