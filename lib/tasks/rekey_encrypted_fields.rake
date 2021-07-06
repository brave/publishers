desc 'Rekey (change keys) of all encrypted fields'
task rekey: :environment do
  old_key = Rails.application.secrets[:attr_encrypted_key].byteslice(0, 32)
  new_key = Rails.application.secrets[:attr_encrypted_key_new].byteslice(0, 32)

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

  # binding.pry

  hash_model_to_columns.each do |model, encrypted_fields|
    encrypted_fields.each do |field|
      rekeyed_field_name = "#{field}_rekeyed"

      records = model.where(rekeyed_field_name => false)
      records.find_each do |record|
        puts "Rekeying #{model} #{field} #{record.id}"

        # Get the old value for later comparison
        field_name_encrypted = record.send("encrypted_#{field}")
        old_field_name_iv = record.send("encrypted_#{field}_iv")

        if field_name_encrypted.blank? or old_field_name_iv.blank?
          puts "Skipping #{model} #{field} #{record.id} due to this field being nil"
          next
        end

        old_iv = Base64.decode64(old_field_name_iv)
        old_field_value = record.class.send("decrypt_#{field}",
                                            field_name_encrypted, iv: old_iv, key: old_key)

        # Perform the rekey on the object in memory using the new key
        Util::AttrEncryptedRekey.rekey(object: record,
                                       field: field,
                                       old_key: old_key,
                                       new_key: new_key)

        # Update the columns but roll back if there was a problem and the new data doesn't match the old
        record.transaction do
          record.update_columns({
            rekeyed_field_name => true,
            "encrypted_#{field}" => record.send("encrypted_#{field}"),
            "encrypted_#{field}_iv" => record.send("encrypted_#{field}_iv"),
          })

          record.reload

          new_iv = Base64.decode64(record.send("encrypted_#{field}_iv"))
          new_field_value = record.class.send("decrypt_#{field}",
                                              field_name_encrypted, iv: new_iv, key: new_key)

          assert old_field_value == new_field_value
        end

        puts "Rekeyed #{model} #{field} #{record.id}"
      rescue OpenSSL::Cipher::CipherError => e
        puts "Cannot rekey #{model} #{field} #{record.id}, error: #{e.message}"
      end
    end
  end
end
