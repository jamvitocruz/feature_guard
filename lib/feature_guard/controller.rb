# frozen_string_literal: true

module FeatureGuard
  # Mixed into ActionController::Base by the Railtie. It provides the `feature`
  # class method for declaring protected features and `module_enabled?` for
  # checking those features in controller actions and views.
  module Controller
    extend ActiveSupport::Concern

    included do
      class_attribute :feature_columns, default: {}

      helper_method :module_enabled?
    end

    # Declares a feature that is protected by the persisted feature setting. The
    # feature is checked before each action, and the user is redirected to the
    # configured dashboard path if the feature is disabled.
    class_methods do
      def feature(module_name, column: nil, **options)
        module_name = module_name.to_sym
        column ||= "#{module_name}_enabled"

        # Build a new, frozen mapping so declarations on one controller do not
        # mutate the mapping inherited by another controller.
        self.feature_columns =
          feature_columns.merge(module_name => column.to_s).freeze

        before_action(**options) do
          enforce_module_availability(module_name)
        end
      end
    end

    # Returns whether a feature is enabled for the current account. Results are
    # cached for the current controller instance, which lasts one request.
    def module_enabled?(module_name)
      module_name = module_name.to_sym

      @module_availability_cache ||= {}

      return @module_availability_cache[module_name] if @module_availability_cache.key?(module_name)

      @module_availability_cache[module_name] = resolve_module(module_name)
    end

    private

    # Redirects instead of continuing to the action when the feature is off.
    def enforce_module_availability(module_name)
      return if module_enabled?(module_name)

      redirect_to(
        feature_guard_redirect_path,
        alert: "#{module_name.to_s.humanize} is not enabled for this account."
      )
    end

    # Asks the controller-owned application policy whether the feature is enabled.
    def resolve_module(module_name)
      policy = feature_guard_policy

      return false unless policy

      policy.feature_enabled?(:"#{feature_column(module_name)}?")
    end

    # Uses an explicitly declared column or the default `<feature>_enabled`.
    def feature_column(module_name)
      self.class.feature_columns.fetch(
        module_name,
        "#{module_name}_enabled"
      )
    end

    # Host controllers must provide the policy instance for the request
    def feature_guard_policy
      namespace = self.class.name.split('::').first
      base_name = namespace.empty? ? 'ApplicationController' : "#{namespace}Controller"

      raise MissingPolicyError,
            "Add #feature_guard_policy to #{base_name}"
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
