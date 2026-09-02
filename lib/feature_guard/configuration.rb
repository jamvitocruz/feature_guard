# frozen_string_literal: true

module FeatureGuard
  class Configuration
    attr_accessor :redirect_method

    def initialize
      # Combined with the controller namespace to build the redirect helper.
      @redirect_method = :root_path
    end
  end
end
