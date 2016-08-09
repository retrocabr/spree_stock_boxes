Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :stock_boxes do
      post 'stocking_check', :on => :collection
    end

    get 'stocking' => 'stock_boxes#stocking'
  end
end
