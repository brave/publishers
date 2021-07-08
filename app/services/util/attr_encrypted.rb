class Util::AttrEncrypted
  # taken from https://github.com/attr-encrypted/attr_encrypted/issues/314
  # Rekey (change the key of) a given field for an object, given the old key.
  # This does not SAVE the user data - do a save afterwards if you want that!
  # This will raise an exception if the old key doesn't work.
  def self.rekey(object:, field:, old_key:, new_key:, field_value:)
    field_name_encrypted = object.send("encrypted_#{field}")
    field_name_iv = object.send("encrypted_#{field}_iv")

    return if field_name_iv.blank? || field_name_encrypted.blank?

    # Change to new value for field; this creates a new IV, re-encrypts,
    # and recalculates the blind index using the current blind index key.
    # This deals with a quirk of attr_encrypted: You have to set the
    # old encrypted_mail value to nil before you can force a re-encrypt.
    object.send("encrypted_#{field}=", nil)
    object.send("#{field}=", field_value)
    object
  end

  def self.get_all_encrypted_fields
    # So we can use ApplicationRecord.descendant even in development
    Rails.application.eager_load!

    models = ApplicationRecord.descendants.each.reject { |model| model.abstract_class }

    hash_model_to_columns = {}
    models.each do |model|
      encrypted_fields = model.
        column_names.
        reject { |field| field.ends_with?('iv') }.
        select { |field| field.starts_with?('encrypted_') }.
        map { |field| field.sub(/^encrypted\_/, '') }
      if encrypted_fields.present?
        hash_model_to_columns[model] = encrypted_fields
      end
    end
    hash_model_to_columns
  end

  def self.get_value_using_key(record:, field:, key:)
    field_name_iv = record.send("encrypted_#{field}_iv")
    field_name_encrypted = record.send("encrypted_#{field}")
    iv = Base64.decode64(field_name_iv)
    record.class.send("decrypt_#{field}",
                      field_name_encrypted,
                      iv: iv,
                      key: record.class.encryption_key(key: key))
  end

  def self.monkey_patch_old_key_fallback
    hash_model_to_columns = Util::AttrEncrypted.get_all_encrypted_fields
    old_key = Rails.application.secrets[:attr_encrypted_key_old]
    new_key = Rails.application.secrets[:attr_encrypted_key]

    hash_model_to_columns.each do |model, encrypted_fields|
      encrypted_fields.each do |field|
        model.class_eval do
          # Redefine the getter method to decrypt using the old key if the new one fails
          # Useful when rotating keys
          # For ex: calling BitflyerConnection.first.refresh_token will hit this method
          # and try to decrypt it using the new key, then old if the new fails
          define_method(field) do
            Util::AttrEncrypted.get_value_using_key(record: self, field: field, key: new_key)
          rescue OpenSSL::Cipher::CipherError
            Util::AttrEncrypted.get_value_using_key(record: self, field: field, key: old_key)
          end
        end
      end
    end
  end
end
