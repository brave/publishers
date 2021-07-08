class Util::AttrEncryptedRekey
  # taken from https://github.com/attr-encrypted/attr_encrypted/issues/314
  # Rekey (change the key of) a given field for an object, given the old key.
  # This does not SAVE the user data - do a save afterwards if you want that!
  # This will raise an exception if the old key doesn't work.
  def self.rekey(object:, field:, old_key:, new_key:, field_value:)
    field_name_encrypted = object.send("encrypted_#{field}")
    field_name_iv = object.send("encrypted_#{field}_iv")

    return if field_name_iv.blank? || field_name_encrypted.blank?
    # old_iv = Base64.decode64(field_name_iv)
    # Get the old field value; this will raise an exception if the
    # given key is wrong.
    # old_field_value = object.class.send("decrypt_#{field}",
    #                                     field_name_encrypted, iv: old_iv, key: old_key)
    # Change to new value for field; this creates a new IV, re-encrypts,
    # and recalculates the blind index using the current blind index key.
    # This deals with a quirk of attr_encrypted: You have to set the
    # old encrypted_mail value to nil before you can force a re-encrypt.
    object.send("encrypted_#{field}=", nil)
    object.send("#{field}=", field_value)
    object
  end
end
