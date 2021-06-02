module Rapidfire
  class Attempt < ActiveRecord::Base
    belongs_to :survey
    belongs_to :user, polymorphic: true
    has_many   :answers, inverse_of: :attempt, autosave: true

    scope :active, -> { where(active: 1) }

    if Rails::VERSION::MAJOR == 3
      attr_accessible :survey, :user
    end
  end
end
