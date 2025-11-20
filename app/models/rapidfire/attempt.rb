module Rapidfire
  class Attempt < ApplicationRecord
    belongs_to :survey
    belongs_to :user, polymorphic: true
    has_many   :answers, inverse_of: :attempt, autosave: true
  end
end
