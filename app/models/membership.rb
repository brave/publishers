class Membership < ApplicationRecord
  belongs_to :organization, class_name: "Organization"

  # Publisher model will be responsible for casting to the right sub-role
  # E.g. casting from Publisher to Partner
  belongs_to :member, class_name: "Publisher", foreign_key: :user_id

  validates_presence_of :organization_id
  validates_presence_of :user_id

  # (Albert Wang) Honestly haven't thought this through as to whether or not an user could be part of different organizations.
  # I think we might allow 1 org for advertising, 1 org for publishing.
  validates_uniqueness_of :user_id, scope: :organization_id
end
