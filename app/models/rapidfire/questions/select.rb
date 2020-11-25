module Rapidfire
  module Questions
    class Select < Rapidfire::Question
      include Cms::CmsInstanceKeys
      sub_key :question_text
      sub_key :answer_options

      validates :answer_options, :presence => true

      def options
        if answer_options == cms_answer_options
          options = answer_options.split(Rapidfire.answers_delimiter)
        else
          options = cms_answer_options.split(",")
        end
      end

      def validate_answer(answer)
        super(answer)

        if rules[:presence] == "1" || answer.answer_text.present?
          answer.validates_inclusion_of :answer_text, :in => options
        end
      end
    end
  end
end
