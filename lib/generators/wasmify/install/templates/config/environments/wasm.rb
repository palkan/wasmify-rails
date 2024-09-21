# frozen_string_literal: true

require_relative "production"

Rails.application.configure do
  config.enable_reloading = false

  config.assume_ssl = false
  config.force_ssl  = false

  config.consider_all_requests_local = ENV["DEBUG"] != "1"

  config.cache_store = :memory_store
  config.active_job.queue_adapter = :inline
  config.action_mailer.delivery_method = :null

  if config.respond_to?(:active_storage)
    config.active_storage.variant_processor = :null
  end

  config.secret_key_base = "<change-me>"
end
