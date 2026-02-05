Rails.application.routes.draw do
  # Authentication routes
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]

  # Google OAuth routes
  get "/auth/google", to: "google_oauth#new", as: :auth_google
  get "/auth/google/callback", to: "google_oauth#callback", as: :auth_google_callback

  # Onboarding (T9.2)
  get "/onboarding", to: "onboarding#index", as: :onboarding
  post "/onboarding", to: "onboarding#update_step"
  patch "/onboarding/calendars", to: "calendars#update_from_onboarding", as: :update_calendars

  # Dashboard
  get "/dashboard", to: "dashboard#index", as: :dashboard

  # Dashboard actions (T4.1)
  namespace :dashboard do
    resources :schedules, only: [] do
      member do
        post :approve
        post :reject
      end
    end
  end

  # Keywords management (T3.1)
  resources :keywords, only: [:index, :create, :destroy] do
    member do
      post :toggle
    end
  end

  # Calendars management (T2.1, T2.2)
  resources :calendars, only: [:index, :update], param: :google_id do
    collection do
      post :refresh
    end
  end

  # Watermark tool
  resources :watermarks, only: [:index, :create]

  # Schedules list and detail (T4.2)
  resources :schedules, only: [:index, :show, :edit, :update, :destroy] do
    collection do
      post :sync  # Google Calendar 동기화
    end
    member do
      delete :cancel  # 수동 취소
    end
  end

  # Settings (T9.2)
  get "/settings/notifications", to: "settings#notifications", as: :notifications_settings
  patch "/settings/notifications", to: "settings#update_notifications"
  get "/settings/telegram", to: "settings#telegram", as: :telegram_settings
  post "/settings/telegram/link", to: "settings#link_telegram", as: :link_telegram_settings
  post "/settings/telegram/test", to: "settings#test_telegram", as: :test_telegram_settings
  delete "/settings/telegram/unlink", to: "settings#unlink_telegram", as: :unlink_telegram_settings

  # Account settings
  get "/settings/account", to: "settings#account", as: :account_settings
  patch "/settings/account", to: "settings#update_account"
  patch "/settings/account/password", to: "settings#update_password", as: :update_password_settings
  delete "/settings/account", to: "settings#destroy_account", as: :destroy_account_settings

  # Telegram webhook
  post "/telegram/webhook", to: "telegram_webhooks#callback"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root
  root "sessions#new"
end
