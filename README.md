[![Gem](https://img.shields.io/gem/v/u-authorization.svg?style=flat-square)](https://rubygems.org/gems/u-authorization)
[![Build Status](https://github.com/serradura/u-authorization/actions/workflows/ci.yml/badge.svg)](https://github.com/serradura/u-authorization/actions/workflows/ci.yml)
[![Maintainability](https://qlty.sh/gh/serradura/projects/u-authorization/maintainability.svg)](https://qlty.sh/gh/serradura/projects/u-authorization)
[![Code Coverage](https://qlty.sh/gh/serradura/projects/u-authorization/coverage.svg)](https://qlty.sh/gh/serradura/projects/u-authorization)
<br/>
![Ruby](https://img.shields.io/badge/Ruby%20%3E%3D%202.7%2C%20%3C%3D%20Head-ruby.svg?colorA=444&colorB=333)
![Rails](https://img.shields.io/badge/Rails%20%3E%3D%206.0-rails.svg?colorA=444&colorB=333)

# µ-authorization

Simple authorization library and role managment for Ruby.

## Required Ruby version

> \>= 2.7.0

## Installation

Add this line to your application's Gemfile:
```
gem 'u-authorization'
```

And then execute:
```
$ bundle
```

Or install it yourself as:
```
$ gem install u-authorization
```

## Usage

```ruby
  require 'ostruct'
  require 'u-authorization'

  module Permissions
    ADMIN = {
      'visit'  => { 'any' => true },
      'export' => { 'any' => true }
    }

    USER = {
      'visit'  => { 'except' => ['billings'] },
      'export' => { 'except' => ['sales'] }
    }

    ALL = {
      'admin' => ADMIN,
      'user'  => USER
    }

    def self.to(role)
      ALL.fetch(role, 'user')
    end
  end

  user = OpenStruct.new(id: 1, role: 'user')

  class SalesPolicy < Micro::Authorization::Policy
    def edit?(record)
      user.id == record.user_id
    end
  end

  authorization = Micro::Authorization::Model.build(
    permissions: Permissions.to(user.role),
    policies: { default: :sales, sales: SalesPolicy },
    context: {
      user: user,
      to_permit: ['dashboard', 'controllers', 'sales', 'index']
    }
  )

  # Info about the `context` data:
  #   1. :to_permit is a required key
  #     1.1. :permissions is an alternative of :to_permit key.
  #   2. :user is an optional key
  #   3. Any key different of :permissions, will be passed as a policy context.

  # Verifying the permissions for the given context
  authorization.permissions.to?('visit')  #=> true
  authorization.permissions.to?('export') #=> false

  # Verifying permission for a given feature in different contexts
  has_permission_to = authorization.permissions.to('export')
  has_permission_to.context?('billings') #=> true
  has_permission_to.context?('sales')    #=> false

  charge = OpenStruct.new(id: 2, user_id: user.id)

  # The #to() method fetch and build a policy.
  authorization.to(:sales).edit?(charge)   #=> true

  # :default is the only permitted key to receive
  # another symbol as a value (a policy reference).
  authorization.to(:default).edit?(charge) #=> true

  # #policy() method has a similar behavior of #to(),
  # but if there is a policy defined as ":default", it will be fetched and instantiated by default.
  authorization.policy.edit?(charge)         #=> true
  authorization.policy(:sales).edit?(charge) #=> true

  # Cloning the authorization changing only its context.
  new_authorization = authorization.map(context: [
    'dashboard', 'controllers', 'billings', 'index'
  ])

  new_authorization.permissions.to?('visit') #=> false

  authorization.equal?(new_authorization) #=> false

  #========================#
  # Multi role permissions #
  #========================#

  authorization = Micro::Authorization::Model.build(
    permissions: [Permissions::USER, Permissions::ADMIN], # An array of permissions
    policies: { default: :sales, sales: SalesPolicy },
    context: {
      user: user,
      to_permit: ['dashboard', 'controllers', 'sales', 'index']
    }
  )

  authorization.permissions.to?('visit')  #=> true
  authorization.permissions.to?('export') #=> true

  has_permission_to = authorization.permissions.to('export')
  has_permission_to.context?('billings') #=> true
  has_permission_to.context?('sales')    #=> true
```

## Original implementation

https://gist.github.com/serradura/7d51b979b90609d8601d0f416a9aa373
