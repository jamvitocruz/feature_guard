# frozen_string_literal: true

# `FeatureGuard::Controller` is an ActiveSupport concern and uses
# `class_attribute` to keep each controller's feature declarations.
require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'

require_relative 'feature_guard/version'
require_relative 'feature_guard/configuration'
require_relative 'feature_guard/policy'
require_relative 'feature_guard/controller'
require_relative 'feature_guard/railtie'

module FeatureGuard
  # Custom error classes for the gem
  class MissingFeatureColumnError < StandardError; end
  class MissingRouteError < StandardError; end
  class MissingPolicyError < StandardError; end

  class << self
    attr_writer :configuration

    # Returns one shared configuration object for the application. The object
    # is created only on first use, then kept in memory for later calls.
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the shared configuration object so an initializer can customize
    # the application policy and redirect path.
    def configure
      yield(configuration)
    end
  end
end
