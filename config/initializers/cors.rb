Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '*', 
      headers: :any, 
      methods: [:get, :post],
      expose: ['Content-Length', 'Content-Range']
    resource '*', 
      headers: :any, 
      methods: [:options],
      max_age: 1728000 # Tell client that this pre-flight info is valid for 20 days
  end
end
