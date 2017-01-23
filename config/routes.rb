Rails.application.routes.draw do

  if Rails.env.development?
    get '/doc', to: redirect("http://saas.railskit.com")
  end

end
