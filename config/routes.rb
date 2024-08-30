DiscourseCategoryRestrictor::Engine.routes.draw do
  get 'restrict/:category_id/users' => 'category_restrictor#index'
  post 'restrict/:category_id/:user_id/:restriction_type' => 'category_restrictor#create_or_update'
  delete 'restrict/:category_id/:user_id/:restriction_type' => 'category_restrictor#destroy'
end

Discourse::Application.routes.append do
  mount ::DiscourseCategoryRestrictor::Engine, at: "/category-restrictor"
end