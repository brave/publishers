# frozen_string_literal: true

class Invoice < ApplicationRecord
  class ReadOnlyError < StandardError; end

  belongs_to :publisher

  belongs_to :uploaded_by, class_name: "Publisher"
  belongs_to :paid_by, class_name: "Publisher"
  belongs_to :finalized_by, class_name: "Publisher"

  has_many :invoice_files, -> { order(created_at: :desc) }

  URL_DATE_FORMAT = "%Y-%m"

  IN_PROGRESS = "in progress"
  PENDING = "pending"
  PAID = "paid"

  STATUS_FIELDS = [PENDING, PAID, IN_PROGRESS].freeze

  validates :publisher_id, :date, presence: true
  validates :status, inclusion: { in: STATUS_FIELDS }

  validates :date, uniqueness: { scope: :publisher_id }

  # Ensure these two values are numbers even though field is a string
  validates :amount, numericality: true, allow_nil: true
  validates :finalized_amount, numericality: true, allow_blank: true

  def human_date
    if date.day == 1
      date.strftime("%B %Y")
    else
      date.strftime("%B %d, %Y")
    end
  end

  def in_progress?
    status == IN_PROGRESS
  end

  def pending?
    status == PENDING
  end

  def paid?
    status == PAID
  end

  def finalized_amount_to_probi
    if finalized_amount
      (finalized_amount.tr(",", "").to_d * BigDecimal("1.0e18")).to_i
    else
      0
    end
  end

  def as_json(_options = {})
    {
      id: id,
      amount: amount,
      status: status.titleize,
      date: human_date,
      url: Rails.application.routes.url_helpers.partners_payments_invoice_path(date.in_time_zone("UTC").strftime(URL_DATE_FORMAT)),
      files: invoice_files.where(archived: false).as_json.compact,
      paid: paid?,
      paymentDate: payment_date,
      finalizedAmount: finalized_amount,
      createdAt: created_at.strftime("%b %d, %Y"),
    }
  end
end
