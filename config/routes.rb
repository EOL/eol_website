Rails.application.routes.draw do

  # Putting pages first only because it"s the most common:
  # TODO: move all the silly extra things to their own resources (I think).
  resources :pages, only: [:show] do
    get "traits"
    get "article"
    get "maps"
    get "classifications"
    get "details"
    get "names"
    get "literature_and_references"
  end

  # Putting users second only because they tend to drive a lot of site behavior:
  devise_for :users, controllers: { registrations: "user/registrations",
                                    sessions: "user/sessions",
                                    omniauth_callbacks: "user/omniauth_callbacks"}
  resources :users do
    collection do
      post "delete_user", defaults: { format: "json" }
    end
  end

  # All of the "normal" resources:
  resources :collections
  resources :collection_associations, only: [:new, :create]
  resources :collected_pages, only: [:new, :create] do
    collection do
      get "search", defaults: { format: "json" }
      get "search_results"
    end
  end
  resources :media, only: [:show]
  resources :open_authentications, only: [:new, :create]
  resources :page_icons, only: [:create]
  resources :resources, only: [:show]

  get "/terms" => "terms#show", :as => "term"

  # Non-resource routes last:
  get "/search" => "search#search", :as => "search"
  get "/clade_filter" => "terms#clade_filter", :as => "clade_filter"

  # TODO: Change. We really want this to point to a (dynamic) CMS page of some
  # sort.
  root "users#index"
end
