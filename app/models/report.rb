class Report < ActiveRecord::Base
  belongs_to :partner
  belongs_to :uploaded_by, class_name: "Publisher"

  has_one_attached :file

  def filename
    self.file.filename if self.file.attached?
  end

  def as_json(options={})
    {
      id: self.id,
      filename: self.file.filename,
      file_url: Rails.application.routes.url_helpers.rails_blob_path(self.file, disposition: "attachment", only_path: true),
      uploaded_by_user: self.uploaded_by.name,
      created_at: self.created_at.strftime("%b %d, %Y")
    }
  end
end
