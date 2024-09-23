# frozen_string_literal: true

module ActionMailer
  class NullDeliveryMethod
    def initialize(*)
    end

    def deliver!(_)
    end
  end
end

ActiveSupport.on_load(:action_mailer) do
  ActionMailer::Base.add_delivery_method :null, ActionMailer::NullDeliveryMethod
end
