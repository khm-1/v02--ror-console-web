Rails.application.routes.draw do
  resources :posts
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "page#home"

  get "page/about", as: :about
  # resources :posts, only: [:home, :about], controller: "page"
  resources :posts

  # Web Console routes
  get "console", to: "console#index"
  post "console/execute", to: "console#execute"
  delete "console/clear_history", to: "console#clear_history"
  
  # Console session management routes
  post "console/new_session", to: "console#new_session"
  get "console/session_list", to: "console#session_list"
  post "console/select_session", to: "console#select_session"
  put "console/select_session/:session_id", to: "console#select_session"
  delete "console/close_session", to: "console#close_session"
  delete "console/close_session/:session_id", to: "console#close_session"
  
  # Sandbox Console routes (more restricted)
  get "console/sandbox", to: "console#sandbox"
  post "console/sandbox/execute", to: "console#sandbox_execute"
  delete "console/sandbox/clear_history", to: "console#sandbox_clear_history"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
