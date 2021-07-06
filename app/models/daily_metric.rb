# frozen_string_literal: true

class DailyMetric < ApplicationRecord
  validates_presence_of :name, :result, :date
end
