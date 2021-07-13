class Organization < ApplicationRecord
  has_many :memberships
  has_many :members, through: :memberships
  has_one :organization_permission

  alias_attribute :permissions, :organization_permission

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :organization_permission, presence: true

  def to_s
    name
  end
end
