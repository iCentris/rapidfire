module Rapidfire
  module Questions
    class Long < Rapidfire::Question
      include Cms::CmsInstanceKeys
      sub_key :question_text
    end
  end
end
