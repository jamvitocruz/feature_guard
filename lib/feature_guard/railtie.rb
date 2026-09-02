# frozen_string_literal: true

require 'rails/railtie'

module FeatureGuard
  class Railtie < Rails::Railtie
    initializer 'feature_guard.controller' do
      ActiveSupport.on_load(:action_controller_base) do
        # Makes FeatureGuard available to every controller through inheritance.
        # Applications can override methods such as `feature_guard_policy` in
        # their base controller to provide request-specific behavior.
        include FeatureGuard::Controller
      end
    end
  end
end
