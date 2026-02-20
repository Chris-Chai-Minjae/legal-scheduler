class Expense < ApplicationRecord
  belongs_to :card_statement
  belongs_to :user

  enum :classification_status, { pending: 0, classified: 1, failed: 2, manual: 3 }

  validates :transaction_date, presence: true
  validates :amount, presence: true
  validates :card_name, presence: true

  scope :unclassified, -> { where(classification_status: :pending) }
  scope :classified, -> { where(classification_status: [:classified, :manual]) }
  scope :by_date, -> { order(transaction_date: :desc) }
  scope :by_card, ->(name) { where(card_name: name) }
  scope :by_category, ->(cat) { where(category: cat) }

  CATEGORIES = %w[출장비 소모품구입비 임금 잡비 보험료 복리후생비 관리비 임차료 통신비].freeze

  def formatted_amount
    "#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}원"
  end
end
