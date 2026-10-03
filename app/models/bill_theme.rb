class BillTheme < ApplicationRecord
  belongs_to :bill
  belongs_to :theme
end
