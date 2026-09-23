class MessagePolicy < ApplicationPolicy
  def create?
    record.chat.user == user
  end
end
