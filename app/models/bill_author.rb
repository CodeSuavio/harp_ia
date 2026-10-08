class BillAuthor < ApplicationRecord
  belongs_to :bill
  belongs_to :deputy

  validates :deputy_id, uniqueness: { scope: :bill_id }
end
