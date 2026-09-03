# frozen_string_literal: true

module FeatureGuard
  # Mixed into ActionController::Base by the Railtie. It provides the `feature`
  # class method for declaring protected features and `module_enabled?` for
  # checking those features in controller actions and views.
  module Controller
    extend ActiveSupport::Concern

    included do
      class_attribute :policy_name, default: :feature_guard_policy

      helper_method :module_enabled?
    end

    # Declares a feature that is protected by the persisted feature setting. The
    # feature is checked before each action, and the user is redirected to the
    # configured path if the feature is disabled.
    class_methods do
      # Selects the controller instance method that builds the request policy.
      # Without this declaration, FeatureGuard calls `#feature_guard_policy`.
      def feature_guard_policy_method(method_name)
        self.policy_name = method_name.to_sym
      end

      def feature(feature_name, **options)
        feature_name = feature_name.to_sym

        if feature_name.to_s.end_with?('?')
          raise ArgumentError,
                'Feature name must not end with a question mark. Use :inventory_enable instead of :inventory_enable?.'
        end

        before_action(**options) do
          enforce_module_availability(feature_name)
        end
      end
    end

    # Returns whether a feature is enabled for the current account. Results are
    # cached for the current controller instance, which lasts one request.
    def module_enabled?(feature_name)
      feature_name = feature_name.to_sym

      @module_availability_cache ||= {}

      return @module_availability_cache[feature_name] if @module_availability_cache.key?(feature_name)

      @module_availability_cache[feature_name] = resolve_module(feature_name)
    end

    private

    # Redirects instead of continuing to the action when the feature is off.
    def enforce_module_availability(module_name)
      return if module_enabled?(module_name)

      redirect_to(
        feature_guard_redirect_path,
        alert: 'This feature is not available for your account.'
      )
    end

    # Asks the controller-owned application policy whether the feature is enabled.
    def resolve_module(feature_name)
      policy = feature_guard_policy_instance

      return false unless policy

      policy.public_send(:"#{feature_name}?")
    end

    # Calls the policy factory selected by `feature_guard_policy`. Policy
    # factories may be private methods on the application's base controller.
    def feature_guard_policy_instance
      policy_method = self.class.policy_name

      return feature_guard_policy if policy_method == :feature_guard_policy

      send(policy_method)
    end

    # Host controllers must provide the policy instance for the request
    def feature_guard_policy
      namespace = self.class.name.split('::').first
      base_name = namespace.empty? ? 'ApplicationController' : "#{namespace}Controller"

      raise MissingPolicyError,
            "Define #feature_guard_policy in #{base_name}, or configure a custom policy with feature_guard_policy_method"
    end

    def feature_guard_redirect_path
      namespace = controller_path.split('/').first
      dashboard_path = :"#{namespace}_#{FeatureGuard.configuration.redirect_method}"

      return public_send(dashboard_path) if respond_to?(dashboard_path)

      raise MissingRouteError,
            "Expected route helper #{dashboard_path} for #{self.class.name}"
    end
  end
end
