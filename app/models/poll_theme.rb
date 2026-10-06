class PollTheme < ApplicationRecord
  belongs_to :poll
  belongs_to :theme
end
