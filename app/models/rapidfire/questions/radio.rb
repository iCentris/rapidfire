module Rapidfire
  module Questions
    class Radio < Select
      include Cms::CmsInstanceKeys
      sub_key :question_text
      sub_key :answer_options

      def options
        if answer_options == cms_answer_options
          options = answer_options.split(Rapidfire.answers_delimiter)
        else
          options = cms_answer_options.split(",")
        end
      end
    end
  end
end
