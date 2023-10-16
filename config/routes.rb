# frozen_string_literal: true

Rails.application.routes.draw do
  resources :tasks do
    resources :task_items
  end

  get '/companies/:company_id/softwares', to: 'welcome#softwares_by_company_id'
  get '/softwares', to: 'welcome#softwares'
  get '/companies', to: 'welcome#companies'

  root 'welcome#index'
end
