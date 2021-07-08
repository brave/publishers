desc 'Rekey (change keys) of all encrypted fields'
task rekey: :environment do
  old_key = Rails.application.secrets[:attr_encrypted_key_old]
  new_key = Rails.application.secrets[:attr_encrypted_key]

  hash_model_to_columns = Util::AttrEncrypted.get_all_encrypted_fields

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

        old_field_value = Util::AttrEncrypted.get_value_using_key(record: record,
                                                                  field: field,
                                                                  key: old_key)
        # Perform the rekey on the object in memory using the new key
        Util::AttrEncrypted.rekey(object: record,
                                  field: field,
                                  old_key: old_key,
                                  new_key: new_key,
                                  field_value: old_field_value)

        # Update the columns but roll back if there was a problem and the new data doesn't match the old
        record.transaction do
          record.update_columns({
            rekeyed_field_name => true,
            "encrypted_#{field}" => record.send("encrypted_#{field}"),
            "encrypted_#{field}_iv" => record.send("encrypted_#{field}_iv"),
          })

          record.reload

          new_field_value = Util::AttrEncrypted.get_value_using_key(record: record,
                                                                    field: field,
                                                                    key: new_key)
          if old_field_value != new_field_value
            raise RuntimeError("Values don't match! Old: #{old_field_value} New: #{new_field_value}")
          end
        end

        puts "Rekeyed #{model} #{field} #{record.id}"
      rescue OpenSSL::Cipher::CipherError => e
        puts "Cannot rekey #{model} #{field} #{record.id}, error: #{e.message}"
      end
    end
  end
end
