class InvoiceFile < ApplicationRecord
  belongs_to :invoice
  belongs_to :uploaded_by, class_name: "Publisher"

  has_one_attached :file

  validates :file, presence: true

  def active_files
    invoice.invoice_files.where(archived: false)
  end

  def as_json(_options = {})
    return unless file.attached?
    {
      id: id,
      file: {
        name: file.filename,
        url: Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "attachment", only_path: true),
      },
      canArchive: uploaded_by.invoice? && invoice.pending?,
      archived: archived,
      url: Rails.application.routes.url_helpers.partners_payments_invoice_invoice_file_url(invoice_id: "_", id: id, only_path: true),
      uploadedBy: uploaded_by.name,
      createdAt: created_at.strftime("%b %d, %Y"),
    }
  end
end
