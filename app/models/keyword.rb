# @TASK T0.2 & T9.2 - Keyword model for calendar event filtering
# @SPEC docs/planning/04-database-design.md#keywords-table

class Keyword < ApplicationRecord
  belongs_to :user

  # Alias for UI compatibility (T9.2)
  # Database uses 'keyword' column, but views use 'name'
  alias_attribute :name, :keyword

  validates :user_id, :keyword, presence: true
  validates :keyword, uniqueness: { scope: :user_id }

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
end
