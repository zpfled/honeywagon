Rails.application.routes.draw do
  resources :orders do
    collection do
      get :availability
    end
    member do
      post :schedule
      post :reschedule_service_events
    end

    resources :service_events, only: %i[create destroy], module: :orders do
      patch :assign_route, on: :member
    end
  end
  resources :service_events, only: :update
  resources :routes, only: [ :show, :create, :update ] do
    get :calendar, on: :collection
    post :merge, on: :member
    post :push_to_calendar, on: :member
    resources :service_events, only: [], module: :routes do
      post :postpone, on: :member
      post :advance, on: :member
      post :complete, on: :member
      post :skip, on: :member
      delete :destroy, on: :member
    end
    resources :dump_events, only: :create, module: :routes
    resource :optimization, only: :create, module: :routes
    # TODO: paginate route stops if lists grow large (consider turbo streams)
    resource :ordering, only: :update, module: :routes
  end
  resources :service_event_reports, only: [ :index, :new, :create, :edit, :update ] # TODO: paginate index
  namespace :setup do
    resource :company, only: %i[show update]
  end
  resource :company, only: %i[edit update], controller: 'company' do
    collection do
      get :customers
      get :expenses
      get :new_unit_type
      get :new_rate_plan
      get :new_trailer
      get :new_customer
      get :new_expense
    end
  end
  namespace :api do
    get 'places/autocomplete', to: 'places#autocomplete', as: :places_autocomplete
    get 'places/details', to: 'places#details', as: :places_details
  end
  resources :locations, only: [ :new, :create ]
  resources :trucks, only: %i[edit update]
  resources :trailers, only: %i[edit update]
  resources :rate_plans, only: [ :new, :create ]
  resources :customers, only: [ :new, :create ]
  get 'google_calendar/connect', to: 'google_calendars#connect', as: :google_calendar_connect
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  authenticated :user do
    root to: 'dashboard#index', as: :authenticated_root
  end

  get 'dashboard/capacity_routing_preview', to: 'dashboard#capacity_routing_preview', as: :capacity_routing_preview

  unauthenticated do
    root to: 'public#landing', as: :unauthenticated_root
  end
end
