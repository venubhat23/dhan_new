Rails.application.routes.draw do
  # Vendor invoice public view
  get '/vendor_invoice/:token', to: 'vendor_invoices#public_view', as: 'vendor_invoice_public'
  # Product Reviews
  resources :products, only: [:show] do
    resources :product_reviews, only: [:create, :update, :destroy] do
      member do
        patch :mark_helpful
      end
    end
  end

  resources :product_reviews, only: [:show]
  get "dashboard/index"
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  # Custom sign_out route to handle GET requests
  devise_scope :user do
    get '/users/sign_out' => 'users/sessions#destroy'
  end

  # Custom sessions for login
  resource :sessions, only: [:new, :create, :destroy]

  # User login routes
  namespace :user do
    get '/login', to: 'sessions#new'
    post '/login', to: 'sessions#create'
    delete '/logout', to: 'sessions#destroy'
  end

  # Root route - Marali Santhe website
  root 'home#index'

  # Public pages
  get 'adhika/privacy-policy', to: 'public_pages#adhika_privacy_policy'
  get 'adhika/account-deletion-policy', to: 'public_pages#adhika_account_deletion_policy'

  # Public invoices list (no authentication required)
  get '/invoices_public', to: 'public_invoices#index', as: 'public_invoices'
  get '/invoices_public/:token', to: 'public_invoices#show', as: 'public_invoice_by_token'
  patch '/invoices_public/:id/complete', to: 'public_invoices#complete', as: 'public_invoice_complete'
  delete '/invoices_public/:id', to: 'public_invoices#destroy', as: 'public_invoice_delete'

  # Test route for booking invoices controller
  get '/test_invoice', to: 'booking_invoices#test'

  # Public invoice view (no authentication required)
  get '/invoice/:token', to: 'booking_invoices#public_view', as: 'public_invoice'
  get '/invoice/:token/download', to: 'booking_invoices#public_download_pdf', as: 'public_invoice_download', defaults: { format: :pdf }

  # Dashboard
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/beautiful', to: 'dashboard#beautiful'
  get 'dashboard/ultra', to: 'dashboard#ultra'
  get 'dashboard/ecommerce', to: 'dashboard#ecommerce'
  get 'dashboard/modern', to: 'dashboard#modern'
  get 'dashboard/dummy', to: 'dashboard#dummy'
  get 'dashboard/stats', to: 'dashboard#stats'


  # API routes
  namespace :api do
    resources :cities, only: [:index]

    # Delivery validation APIs
    post 'delivery/check_product', to: 'delivery#check_product_delivery'
    post 'delivery/check_cart', to: 'delivery#check_cart_delivery'
    get 'delivery/available_pincodes/:product_id', to: 'delivery#available_pincodes'

    namespace :v1 do
      # Public API endpoints (no authentication required)
      get 'public/search_sub_agents', to: 'public#search_sub_agents'
    end
  end

  # Admin routes
  namespace :admin do
    # Bookings Management (Now handles complete order workflow)
    resources :bookings do
      member do
        get :generate_invoice
        post :generate_invoice
        post :convert_to_order
        get :invoice
        patch :update_status
        patch :cancel_order
        patch :mark_delivered
        patch :mark_completed
        get :stage_transition
        get :manage_stage
        patch :process_stage_transition
        patch :update_stage
      end
      collection do
        get :search_products
        get :search_customers
        get :realtime_data
        # Status filters
        get :pending
        get :confirmed
        get :processing
        get :packed
        get :shipped
        get :out_for_delivery
        get :delivered
        get :completed
        get :cancelled
        get :returned
      end
    end

    # Orders Management
    resources :orders do
      member do
        patch :update_status
        patch :ship
        patch :deliver
        patch :cancel
        get :invoice
        get :tracking
      end
      collection do
        get :pending
        get :processing
        get :shipped
        get :delivered
        get :cancelled
      end
    end

    # Document management
    resources :documents do
      member do
        get :download
      end
    end

    # Nested document routes for different models
    resources :users do
      resources :documents, except: [:edit, :update]
    end


    resources :customers do
      resources :documents, except: [:edit, :update]
    end
    resources :payouts do
      member do
        patch :mark_as_paid
        patch :mark_as_processing
        patch :cancel_payout
        get :audit_trail
        get :flow_timeline
      end
      collection do
        get :commission_receipts
        post :auto_distribute
        get :reports
        get :summary
      end
    end

    # Commission Tracking System
    resources :commission_tracking, only: [:index, :show, :update] do
      member do
        patch :transfer_to_affiliate
        patch :transfer_to_ambassador
        patch :transfer_to_investor
        patch :transfer_company_expense
        patch :mark_main_agent_commission_received
        get :policy_breakdown
      end
      collection do
        get :dashboard
        get :modern_dashboard
        get :summary
        get :policy_search
        post :manual_transfer
      end
    end

    # Affiliate Payout System
    resources :affiliate_payouts, only: [:index, :show] do
      collection do
        post :mark_as_paid
        get :unpaid_data
      end
    end

    # Distributor Payout System
    resources :distributor_payouts, only: [:index, :show] do
      collection do
        post :mark_as_paid
        get :unpaid_data
      end
    end

    # Payout 2 System - Comprehensive Payout Management
    resources :payout2, only: [:index] do
      collection do
        patch :mark_as_paid
        get :commission_breakdown
      end
    end

    # Invoice System
    resources :invoices do
      member do
        patch :mark_as_paid
        get :download_pdf
        get :show_premium
        get :download_premium_pdf
      end
      collection do
        post :generate_invoice
        post :generate_bulk_invoices
        post :bulk_mark_as_paid
        post :partial_payment
        get :customers
        get :delivery_persons
        get :customers_by_delivery_person
        post :generate
      end
    end

    # Booking Invoice System
    resources :booking_invoices do
      member do
        patch :mark_paid
        get :download_pdf
      end
    end

    # Pending Amounts Management
    resources :pending_amounts, only: [:index, :create, :update, :destroy]

    # Notes Management - Payment Tracking
    resources :notes

    # Invoice Check Management
    get 'invoice_check', to: 'invoice_check#index', as: :invoice_check
    post 'invoice_check/check', to: 'invoice_check#check', as: :invoice_check_check
    post 'invoice_check/generate_invoice/:customer_id', to: 'invoice_check#generate_invoice', as: :invoice_check_generate

    # Users (Admins/Agents) management
    resources :users

    # Roles and Permissions management
    resources :roles do
      member do
        patch :toggle_status
        post :assign_users
      end
      collection do
        get :permissions_preview
      end
    end

    resources :permissions do
      member do
        # Individual permission management
      end
      collection do
        post :generate_defaults
        get :bulk_assign
        post :bulk_update
        get 'module/:module_name', action: :module_permissions, as: :module
      end
    end

    # Sub Agent management (legacy)
    resources :sub_agents do
      member do
        patch :toggle_status
        get :distributor
        get :documents
      end
      resources :sub_agent_documents, except: [:show, :index]
    end

    # Distributor management
    resources :distributors do
      member do
        patch :toggle_status
      end
    end

    # Investor management
    resources :investors do
      member do
        patch :toggle_status
      end
      resources :investor_documents, only: [:destroy]
    end

    # Customer management
    resources :customers do
      collection do
        get :export
        get :cities
        get :search_sub_agents
      end
      member do
        patch :toggle_status
        get :policy_chart
        get :trace_commission
        get :product_selection
        post :generate_password
      end
      resources :family_members
    end

    # Store management
    resources :stores do
      member do
        patch :toggle_status
      end
    end

    # Customer Format Management
    resources :customer_formats do
      member do
        patch :toggle_status
      end
      collection do
        get :search_customers
        get :search_products
        get :search_delivery_people
        get :import_page
        post :import_from_master
      end
    end

    # Subscription Management
    resources :subscriptions do
      member do
        patch :toggle_status
        patch :pause_subscription
        patch :resume_subscription
        get :delivery_schedule
        post :generate_tasks
        get :daily_tasks
      end
      collection do
        get :active
        get :paused
        get :expired
        post :generate_all_daily_tasks
      end
    end

    # Subscription Templates Management
    resources :subscription_templates do
      member do
        patch :toggle_status
        post :apply_to_customer
      end
      collection do
        get :active
      end
    end

    # Milk Delivery Tasks Management
    resources :milk_delivery_tasks, only: [:update, :destroy] do
      member do
        patch :complete
        patch :cancel
        patch :pause
        patch :resume
      end
      collection do
        post :bulk_update
        post :bulk_complete
        post :bulk_delete
        post :bulk_cancel
      end
    end

    # Banner management
    resources :banners do
      member do
        patch :toggle_status
      end
      collection do
        post :upload_cloudinary_image
        post :upload_r2_image
        delete :delete_r2_image
      end
    end

    # Client Request management
    resources :client_requests do
      member do
        patch :update_status
        patch :mark_resolved
        post :add_response
      end
      collection do
        get :pending
        get :in_progress
        get :resolved
        get :closed
      end
    end

    # Referrals management
    resources :referrals do
      member do
        patch :mark_registered
        patch :mark_converted
        patch :update_status
      end
      collection do
        get :analytics
        get :customer_referrals
        get :affiliate_referrals
      end
    end

    # Vendor management
    resources :vendors do
      member do
        patch :toggle_status
      end
    end

    # Vendor Purchase management
    resources :vendor_purchases do
      member do
        get :complete_purchase
        patch :complete_purchase
        post :complete_purchase
        post :generate_invoice
        get :mark_as_paid
        patch :mark_as_paid
      end
      collection do
        get :batch_inventory
        post :bulk_mark_as_paid
      end
    end

    # Franchise management
    resources :franchises do
      collection do
        get :export
      end
      member do
        patch :toggle_status
      end
    end


    # Life Insurance
    resources :life_insurances, path: 'insurance/life' do
      collection do
        get :policy_holder_options
        get :brokers_by_company
        get :agency_codes_by_broker
        get :all_agency_codes
        get :all_brokers
      end
      member do
        get :commission_details
        patch :remove_rider
      end
    end

    # Health Insurance
    resources :health_insurances, path: 'insurance/health' do
      collection do
        get :policy_holder_options
      end
    end

    # Motor Insurance
    resources :motor_insurances, path: 'insurance/motor' do
      collection do
        get :policy_holder_options
      end
    end

    # Other Insurance
    resources :other_insurances, path: 'insurance/other'

    # Agency/Broker management
    resources :agency_brokers

    # Broker management
    resources :brokers do
      member do
        patch :toggle_status
      end
      collection do
        get :search
      end
    end

    # Agency Code management
    resources :agency_codes do
      collection do
        get :search
        get :brokers_for_direct
        get :agents_for_broker
        get :all_agents
        get :companies_for_agent
        get :all_brokers
        get :companies_for_broker
        get :all_companies
        get :all_codes
        get :agents_for_code
      end
    end

    # Insurance companies
    resources :insurance_companies

    # Helpdesk management
    resources :helpdesk, path: 'helpdesk' do
      member do
        patch :update_status
        patch :assign_to
        patch :add_response
      end
      collection do
        get :analytics
        get :tickets
        get :knowledge_base
      end
    end

    # Client Requests management
    resources :client_requests do
      member do
        patch :update_status
        patch :assign_to
        patch :add_response
      end
      collection do
        get :pending
        get :in_progress
        get :resolved
        get :search
      end
    end

    # Leads management
    resources :leads do
      resources :documents, except: [:edit, :update]
      member do
        patch :convert_to_customer
        patch :create_policy
        patch :transfer_referral
        patch :advance_stage
        patch :go_back_stage
        patch :update_stage
        patch :convert_stage
        patch :mark_not_interested
        patch :close_lead
      end
      collection do
        get :export
        get :statistics
        patch :bulk_update_stage
        get :check_existing_customer
        get :search_sub_agents
      end
    end

    # Banner management
    resources :banners do
      member do
        patch :toggle_status
      end
    end

    # Reports
    get 'reports/commission', to: 'reports#commission'
    get 'reports/expired_insurance', to: 'reports#expired_insurance'
    get 'reports/payment_due', to: 'reports#payment_due'
    get 'reports/upcoming_renewal', to: 'reports#upcoming_renewal'
    get 'reports/upcoming_payment', to: 'reports#upcoming_payment'
    get 'reports/leads', to: 'reports#leads'
    get 'reports/sessions', to: 'reports#sessions'
    get 'reports/products', to: 'reports#products'
    get 'reports/customers', to: 'reports#customers'
    get 'reports/revenue', to: 'reports#revenue'
    get 'reports/inventory', to: 'reports#inventory'
    get 'reports/orders', to: 'reports#orders'
    get 'reports/financial', to: 'reports#financial'
    get 'reports/performance', to: 'reports#performance'
    get 'reports/enhanced_sales', to: 'reports#enhanced_sales'

    # Import Section
    resources :imports, only: [:index] do
      collection do
        get :customers_form
        get :sub_agents_form
        get :health_insurances_form
        get :life_insurances_form
        get :motor_insurances_form
        get :delivery_people_form
        get :products_form
        get :customer_subscriptions_form
        get :customer_daily_tasks_form
        get :download_template
        post :validate_csv
      end
    end

    # Import/Export
    post 'import/customers', to: 'imports#customers'
    post 'import/sub_agents', to: 'imports#sub_agents'
    post 'import/health_insurances', to: 'imports#health_insurances'
    post 'import/life_insurances', to: 'imports#life_insurances'
    post 'import/motor_insurances', to: 'imports#motor_insurances'
    post 'import/delivery_people', to: 'imports#delivery_people'
    post 'import/products', to: 'imports#products'
    post 'import/customer_subscriptions', to: 'imports#customer_subscriptions'
    post 'import/customer_daily_tasks', to: 'imports#customer_daily_tasks'
    post 'import/agencies', to: 'imports#agencies'

    # E-commerce Management
    resources :categories do
      member do
        patch :toggle_status
      end
      collection do
        get :search
      end
    end

    resources :products do
      member do
        patch :toggle_status
        post :bulk_action
        get :detail
      end
      collection do
        get :search
        post :bulk_action
        get :categories_for_select
        get :products_chart
        post :upload_cloudinary_image
        post :upload_r2_image
        delete :delete_r2_image
      end
    end

    # Coupons
    resources :coupons do
      member do
        patch :toggle_status
      end
    end

    # Customer Wallets
    resources :customer_wallets do
      member do
        post :add_money
        post :deduct_money
        get :transaction_history
      end
    end

    # Franchises
    resources :franchises do
      member do
        patch :toggle_status
        post :reset_password
      end
    end

    # Affiliates
    resources :affiliates do
      member do
        patch :toggle_status
        patch :reset_password
      end
    end

    # Stock Movements Management
    resources :stock_movements, only: [:index, :show] do
      collection do
        get :summary
        get 'products/:product_id/movements', to: 'stock_movements#product_movements', as: :product_movements
      end
    end

    # Delivery People Management
    resources :delivery_people do
      member do
        patch :toggle_status
      end
      collection do
        post :bulk_action
      end
    end

    # Coupons Management
    resources :coupons do
      member do
        patch :toggle_status
      end
    end

    # Orders Management (Note: Bookings already defined above with full functionality)
    resources :orders

    # Settings namespace
    namespace :settings do
      resources :user_roles do
        member do
          patch :toggle_status
        end
      end

      # System settings (placeholder for future expansion)
      get :system, to: 'system#index'
      patch :system, to: 'system#update'
      put :system, to: 'system#update'
    end
  end

  # Mobile API routes
  namespace :api do
    namespace :v1 do
      # Authentication APIs (Admin/Web)
      post 'auth/login', to: 'authentication#login'
      post 'auth/register', to: 'authentication#register'
      post 'auth/forgot_password', to: 'authentication#forgot_password'
      post 'auth/reset_password', to: 'authentication#reset_password'

      # Mobile API Routes
      namespace :mobile do
        # Mobile Authentication APIs
        post 'auth/login', to: 'authentication#login'
        post 'auth/register', to: 'authentication#register'
        post 'auth/forgot_password', to: 'authentication#forgot_password'

        # E-commerce Module APIs
        get 'ecommerce/categories', to: 'ecommerce#categories'
        get 'ecommerce/categories/:id', to: 'ecommerce#category_details'
        get 'ecommerce/categories/:id/products', to: 'ecommerce#category_products'
        get 'ecommerce/products', to: 'ecommerce#products'
        get 'ecommerce/products/:id', to: 'ecommerce#product_details'
        get 'ecommerce/featured_products', to: 'ecommerce#featured_products'
        get 'ecommerce/search', to: 'ecommerce#search'
        post 'ecommerce/products/:id/check_delivery', to: 'ecommerce#check_delivery'
        get 'ecommerce/filters', to: 'ecommerce#filters'
        get 'ecommerce/banners', to: 'ecommerce#banners'

        # Booking APIs
        post 'ecommerce/bookings', to: 'ecommerce#create_booking'
        get 'ecommerce/bookings', to: 'ecommerce#bookings'

        # Order APIs
        get 'ecommerce/orders', to: 'ecommerce#orders'
        get 'ecommerce/orders/:id', to: 'ecommerce#order_details'

        # Subscription APIs
        post 'ecommerce/subscriptions', to: 'ecommerce#create_subscription'
        get 'ecommerce/subscriptions', to: 'ecommerce#subscriptions'
        get 'ecommerce/subscriptions/:id', to: 'ecommerce#subscription_details'
        put 'ecommerce/subscriptions/:id/pause', to: 'ecommerce#pause_subscription'
        put 'ecommerce/subscriptions/:id/resume', to: 'ecommerce#resume_subscription'
        put 'ecommerce/subscriptions/:id/cancel', to: 'ecommerce#cancel_subscription'

        # Pincode & Delivery Validation APIs
        get 'ecommerce/delivery/check-pincode/:pincode', to: 'ecommerce#check_pincode'
        post 'ecommerce/delivery/validate', to: 'ecommerce#validate_delivery'
        post 'ecommerce/delivery/charges', to: 'ecommerce#delivery_charges'
        post 'ecommerce/location/save', to: 'ecommerce#save_location'

        # Delivery Person APIs
        get 'delivery/tasks/today', to: 'delivery#tasks_today'
        get 'delivery/tasks/:id', to: 'delivery#task_details'
        post 'delivery/tasks/:id/start', to: 'delivery#start_task'
        post 'delivery/tasks/:id/complete', to: 'delivery#complete_task'
        post 'delivery/tasks/:id/update_location', to: 'delivery#update_location'
        post 'delivery/bulk_mark_done', to: 'delivery#bulk_mark_done'
        post 'delivery/bulk_update', to: 'delivery#bulk_update'

        # Customer Profile APIs
        get 'ecommerce/profile', to: 'ecommerce#customer_profile'
        put 'ecommerce/profile', to: 'ecommerce#update_profile'

        # Customer Module APIs
        get 'customer/portfolio', to: 'customer#portfolio'
        get 'customer/upcoming_installments', to: 'customer#upcoming_installments'
        get 'customer/upcoming_renewals', to: 'customer#upcoming_renewals'

        # Settings Module APIs
        get 'settings/profile', to: 'settings#profile'
        put 'settings/profile', to: 'settings#update_profile'
        post 'settings/change_password', to: 'settings#change_password'
        get 'settings/terms', to: 'settings#terms_and_conditions'
        get 'settings/contact', to: 'settings#contact_us'
        post 'settings/helpdesk', to: 'settings#helpdesk'
        get 'settings/notifications', to: 'settings#notification_settings'
        put 'settings/notifications', to: 'settings#update_notification_settings'

        # Agent Dashboard APIs
        get 'agent/dashboard', to: 'agent#dashboard'
        get 'agent/customers', to: 'agent#customers'
        post 'agent/customers', to: 'agent#add_customer'
        get 'agent/form_data', to: 'agent#form_data'
        get 'agent/insurance_companies', to: 'agent#insurance_companies'

        # Leads APIs
        get 'agent/leads', to: 'agent#leads'
        post 'agent/leads', to: 'agent#add_lead'

        # Commission Distribution APIs
        get 'agent/commission_distribution', to: 'agent#commission_distribution'
        get 'agent/commission_summary', to: 'agent#commission_summary'

        # Banner APIs
        get 'banners', to: 'banners#index'
        get 'banners/locations', to: 'banners#locations'
        get 'banners/:id', to: 'banners#show'
        post 'banners/:id/track_click', to: 'banners#track_click'
      end

      # Sub Agent APIs
      resources :sub_agents do
        member do
          patch :toggle_status
        end
      end

      # Customer APIs
      resources :customers do
        member do
          patch :toggle_status
        end
      end

      # Health Insurance APIs
      resources :health_insurances do
        collection do
          get :statistics
          get :form_data
          get :policy_holder_options
        end
      end

      # Life Insurance APIs
      resources :life_insurances do
        collection do
          get :statistics
          get :form_data
          get :policy_holder_options
        end
      end

      # Client Requests APIs
      resources :client_requests do
        member do
          patch :transition_stage
          patch :assign_to_user
          patch :update_priority
          get :stage_history
        end
        collection do
          get :by_stage
          get :by_department
          get :overdue
          get :unassigned
          get :stage_statistics
        end
      end
    end

    # Business Settings
    resource :business_settings, only: [:show, :edit, :update]

    # Profile Management
    resource :profile, only: [:show, :edit, :update]

  end

  # Franchise routes
  namespace :franchise do
    # Authentication routes
    get '/login', to: 'sessions#new'
    post '/login', to: 'sessions#create'
    delete '/logout', to: 'sessions#destroy'

    # Dashboard and main functionality
    root 'dashboard#index'
    get '/dashboard', to: 'dashboard#index'

    # Bookings management (same as admin)
    resources :bookings do
      member do
        get :generate_invoice
        post :generate_invoice
        post :convert_to_order
        get :invoice
        patch :update_status
        patch :cancel_order
        patch :mark_delivered
        patch :mark_completed
        get :stage_transition
        get :manage_stage
        patch :process_stage_transition
        patch :update_stage
      end
      collection do
        get :search_products
        get :search_customers
        get :realtime_data
      end
    end
  end

  # Affiliate routes
  namespace :affiliate do
    # Authentication routes
    get '/login', to: 'sessions#new'
    post '/login', to: 'sessions#create'
    delete '/logout', to: 'sessions#destroy'

    # Dashboard and main functionality
    root 'dashboard#index'
    get '/dashboard', to: 'dashboard#index'

    # Referral management
    resources :referrals do
      collection do
        get :stats
      end
      member do
        patch :mark_registered
        patch :mark_converted
      end
    end

    # Quick refer action
    get '/refer', to: 'referrals#new'
    post '/refer', to: 'referrals#create'

    # Referral history
    get '/referral_history', to: 'referrals#index'
  end

  # Customer Web Application routes
  namespace :customer do
    # Authentication routes
    get '/login', to: 'sessions#new', as: 'login'
    post '/login', to: 'sessions#create'
    delete '/logout', to: 'sessions#destroy', as: 'logout'
    get '/logout', to: 'sessions#logout_redirect'
    get '/register', to: 'registrations#new', as: 'register'
    post '/register', to: 'registrations#create'
    get '/forgot_password', to: 'passwords#new', as: 'forgot_password'
    post '/forgot_password', to: 'passwords#create'
    get '/reset_password', to: 'passwords#edit', as: 'reset_password'
    patch '/reset_password', to: 'passwords#update'

    # Dashboard and main functionality
    root 'dashboard#index'
    get '/dashboard', to: 'dashboard#index'

    # Product catalog
    resources :products, only: [:index, :show] do
      collection do
        get :search
        get :category
      end
    end

    # Categories
    resources :categories, only: [:index, :show]

    # Shopping cart
    resource :cart, only: [:show, :create, :update, :destroy] do
      collection do
        post :add_item
        patch :update_item
        delete :remove_item
        delete :clear
      end
    end

    # Checkout
    resources :checkout, only: [:show, :create] do
      collection do
        get :address
        post :address
        get :payment
        post :payment
        get :confirmation
        post :cart_order
      end
    end

    # Customer addresses
    resources :addresses

    # Orders
    resources :orders, only: [:index, :show] do
      member do
        get :track
        get :invoice
      end
    end

    # Invoices
    resources :invoices, only: [:index, :show] do
      member do
        get :download
      end
    end

    # Subscriptions
    resources :subscriptions do
      member do
        patch :pause
        patch :resume
        patch :cancel
      end
    end

    # Profile management
    resource :profile, only: [:show, :edit, :update] do
      member do
        get :change_password
        patch :update_password
      end
    end

    # Wishlist
    resources :wishlists, only: [:index, :create, :destroy]

    # Notifications
    resources :notifications, only: [:index, :show, :update]

    # Shop functionality
    get 'shop', to: 'shop#index'
    get 'shop/success', to: 'shop#success', as: :shop_success
    get 'shop/category/:id', to: 'shop#category', as: :shop_category
    get 'shop/product/:id', to: 'shop#product', as: :shop_product
    post 'shop/create_booking', to: 'shop#create_booking', as: :create_booking_shop
    post 'shop/cart_order', to: 'shop#cart_order', as: :cart_order_shop

    # Offers
    get 'offers', to: 'offers#index'

    # Support
    get 'support', to: 'support#index'

    # Referrals management
    resources :referrals, only: [:index, :show, :new, :create, :destroy] do
      collection do
        get :success
      end
    end

    # Client requests/support tickets
    resources :client_requests, only: [:index, :show, :new, :create]

    # Delivery Settings management
    resources :delivery_settings
  end

  # Payment Gateway routes
  resources :payment, only: [] do
    collection do
      post :create_order
      get :success
      get :failure
    end
  end

  # Cashfree webhook
  post '/cashfree/webhook', to: 'cashfree#webhook'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
