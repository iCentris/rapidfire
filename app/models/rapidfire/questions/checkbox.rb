module Rapidfire
  module Questions
    class Checkbox < Rapidfire::Question
      include Cms::CmsInstanceKeys
      sub_key :question_text
      sub_key :answer_options

      validates :answer_options, :presence => true
      attr_accessor :default_text
      def placeholder
        ""
      end
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
          answer.answer_text.split(Rapidfire.answers_delimiter).each do |value|
            answer.errors.add(:answer_text, :invalid) unless options.include?(value)
          end
        end
      end
    end
  end
end
