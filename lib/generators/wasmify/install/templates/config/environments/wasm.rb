# frozen_string_literal: true

require_relative "production"

Rails.application.configure do
  config.enable_reloading = false

  config.assume_ssl = false
  config.force_ssl  = false

  # FIXME: Tags are not being reset right now
  config.log_tags = []

  if ENV["DEBUG"] == "1"
    config.consider_all_requests_local = true
    config.action_dispatch.show_exceptions = :none
    config.log_level = :debug
    config.logger = Logger.new($stdout)
  end

  config.cache_store = :memory_store
  config.active_job.queue_adapter = :inline
  config.action_mailer.delivery_method = :null

  if config.respond_to?(:active_storage)
    config.active_storage.variant_processor = :null
  end

  config.secret_key_base = "<change-me>"
end
