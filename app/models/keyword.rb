# @TASK T0.2 - Keyword model for calendar event filtering
# @SPEC docs/planning/04-database-design.md#keywords-table

class Keyword < ApplicationRecord
  belongs_to :user

  validates :user_id, :keyword, presence: true
  validates :keyword, uniqueness: { scope: :user_id }

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
end
