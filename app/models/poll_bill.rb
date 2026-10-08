class PollBill < ApplicationRecord
  belongs_to :poll
  belongs_to :bill

  validates :bill_id, uniqueness: { scope: :poll_id }
end
