# frozen_string_literal: true
require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'
  
  resources :uploads, only: [:new, :create]
  
  resources :tasks do
    resources :task_items

    member do
      post :mark_delivered
    end
  end

  get '/companies/:company_id/softwares', to: 'welcome#softwares_by_company_id'
  get '/softwares', to: 'welcome#softwares'
  get '/companies', to: 'welcome#companies'
  get '/dashboard', to: 'welcome#dashboard'

  root 'welcome#index'
end
