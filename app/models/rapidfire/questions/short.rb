module Rapidfire
  module Questions
    class Short < Rapidfire::Question
      include Cms::CmsInstanceKeys
      sub_key :question_text
    end
  end
end
