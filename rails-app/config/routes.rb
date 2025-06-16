Rails.application.routes.draw do
  root 'home#index'
  get '/health', to: 'home#health'
  get '/metrics', to: 'metrics#index'
end
