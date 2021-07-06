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
    encrypted_fields.each do |encrypted_field|
      rekeyed_field_name = "#{encrypted_field}_rekeyed"

      records = model.where(rekeyed_field_name => false)
      records.find_each do |record|
        Util::AttrEncryptedRekey.rekey(object: record,
                                       field: encrypted_field,
                                       old_key: old_key,
                                       new_key: new_key)
        record.send("#{rekeyed_field_name}=", true)
        record.save!
      rescue OpenSSL::Cipher::CipherError
        Rails.logger.info "Cannot rekey #{model} #{encrypted_field} #{record.id}"
      end
    end
  end
end
