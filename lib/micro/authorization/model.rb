# frozen_string_literal: true

module Micro
  module Authorization
    class Model
      attr_reader :context, :permissions

      def self.build(permissions:, context:, policies: {})
        permissions_context =
          context.delete(:to_permit) || context.delete(:permissions)

        permissions_model =
          Permissions.new(permissions, context: permissions_context)

        self.new(context, permissions: permissions_model, policies: policies)
      end

      def initialize(context, permissions:, policies: {})
        @context = context
        @policies = {}
        @policies_cache = {}
        @permissions = Permissions[permissions]

        add_policies(policies)
      end

      def map(context: nil, policies: nil)
        if context.nil? && policies.nil?
          raise ArgumentError, 'context or policies keywords args must be defined'
        end

        permissions_context = context || permissions.context

        new_permissions =
          Permissions.new(permissions.role, context: permissions_context)

        self.class.new(context, permissions: new_permissions,
                                policies: policies || @policies)
      end

      def add_policy(key, policy_klass)
        raise ArgumentError, 'key must be a Symbol' unless key.is_a?(Symbol)

        default_ref = key == :default && policy_klass.is_a?(Symbol)

        @policies[key] ||= default_ref ? policy_klass : Policy.type(policy_klass)

        self
      end

      def add_policies(new_policies)
        unless new_policies.is_a?(Hash)
          raise ArgumentError, "policies must be a Hash. e.g: `{policy_name: #{Policy.name}}`"
        end

        new_policies.each { |key, policy_klass| add_policy(key, policy_klass) }

        self
      end

      def to(policy_key, subject: nil)
        policy_klass = fetch_policy(policy_key)

        return policy_klass.new(context, subject, permissions: permissions) if subject

        return @policies_cache[policy_key] if @policies_cache[policy_key]

        policy_klass.new(context, permissions: permissions).tap do |instance|
          @policies_cache[policy_key] = instance if policy_klass != Policy
        end
      end

      def policy(key = :default, subject: nil)
        to(key, subject: subject)
      end

      private

      def fetch_policy(policy_key)
        data = @policies[policy_key]
        value = data || @policies.fetch(:default, Policy)
        value.is_a?(Symbol) ? fetch_policy(value) : value
      end
    end
  end
end
