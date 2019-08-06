# frozen_string_literal: true

# Creates a connection between uphold and a channel
#
# We use this to look up existing cards. If a user deletes a channel then we should not destroy this.
# Really the only time we should delete is if the uphold connection gets deleted, which should only happen if the publisher
class UpholdConnectionForChannel < ApplicationRecord
  belongs_to :uphold_connection
  belongs_to :channel

  NETWORK = 'anonymous'
end