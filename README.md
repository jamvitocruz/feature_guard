# FeatureGuard

FeatureGuard protects Rails controller actions with feature flags stored on an
account's settings record. It also exposes the same checks to views.

## Installation

Add the gem to the Rails application's `Gemfile`:

```ruby
gem "feature_guard"
```

Then install dependencies:

```bash
bundle install
```

## Configuration

Create `config/initializers/feature_guard.rb`:

```ruby
FeatureGuard.configure do |config|
  config.redirect_method = :dashboards_path
end
```

The default values are:

```ruby
redirect_method: :root_path
```

`redirect_method` is combined with the controller's first namespace. For
example, `:dashboards_path` in a `Partner` controller becomes
`partner_dashboards_path`.

## Settings record

The account's settings record must have a boolean attribute for each feature:

```ruby
# current_account.feature_setting
inventory_enabled # true or false
reports_enabled   # true or false
```

For example, an account can expose its settings record like this:

```ruby
class Account < ApplicationRecord
  has_one :feature_setting
end
```

## Protect a controller action

Declare a feature in a controller:

```ruby
class InventoryController < ApplicationController
  feature :inventory

  def index
  end
end
```

`feature :inventory` expects `inventory_enabled` on
`current_account.feature_setting`. FeatureGuard adds a `before_action`:

```text
inventory_enabled is true  -> the action runs
inventory_enabled is false -> the request redirects
```

Limit a feature check to specific actions with normal `before_action` options:

```ruby
class InventoryController < ApplicationController
  feature :inventory, only: :index
end
```

Use a custom settings column when needed:

```ruby
feature :inventory, column: :inventory_access_enabled
```

## Feature policy

Create a policy in the Rails application and have the host controller provide
one instance per request. Include `FeatureGuard::Policy`; the module provides
the common feature-resolution behavior.

```ruby
# app/policies/feature_policy.rb
class FeaturePolicy
  include FeatureGuard::Policy
end
```

```ruby
# app/controllers/application_controller.rb
def feature_guard_policy
  @feature_guard_policy ||= FeaturePolicy.new(
    feature_setting: current_account&.feature_setting,
    impersonating: in_impersonation?
  )
end
```

The policy receives the account's `feature_setting` and an optional
`impersonating` value. When impersonating, every feature is enabled.

For any declaration, FeatureGuard maps the feature column to a policy method:

```text
feature :name                         -> name_enabled?
feature :name, column: :custom_access -> custom_access?
```

A policy method returning `true` enables that feature. Returning `false` or
`nil` falls back to the corresponding persisted setting. When the policy does
not define the matching method, the included module's `method_missing` reads
the persisted setting. Its `respond_to_missing?` implementation advertises
these dynamic feature methods to Ruby.

Add `feature_guard_policy` to the base controller so all controllers can use
it. For namespaced controllers, add it to that namespace's base controller. If it is missing, the gem raises
`FeatureGuard::MissingPolicyError`.

## Use a feature in a view

`module_enabled?` is available in controller actions and views:

```erb
<% if module_enabled?(:inventory) %>
  <%= link_to "Inventory", inventory_path %>
<% end %>
```

You may use `module_enabled?` without declaring `feature :inventory` in the
controller. Declaring `feature` is only required when you want FeatureGuard to
add the automatic redirect callback.

## Errors and missing settings

- If the account has no settings record, `module_enabled?` returns `false`.
- If the settings record lacks the expected feature column, FeatureGuard raises
  `FeatureGuard::MissingFeatureColumnError`.
- If the base controller does not implement `feature_guard_policy`, FeatureGuard
  raises `FeatureGuard::MissingPolicyError`.
- If the namespaced dashboard route does not exist, FeatureGuard raises
  `FeatureGuard::MissingRouteError`.
