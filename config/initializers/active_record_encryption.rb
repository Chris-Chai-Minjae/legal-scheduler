# frozen_string_literal: true

# Active Record Encryption configuration from environment variables
Rails.application.config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

# 기존 평문 데이터 호환 (암호화 키 도입 전 저장된 데이터 지원)
Rails.application.config.active_record.encryption.support_unencrypted_data = true
