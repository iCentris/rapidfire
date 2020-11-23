module Rapidfire
  module Questions
    class Date < Rapidfire::Question
      include Cms::CmsInstanceKeys
      sub_key :question_text

      def validate_answer(answer)
        super(answer)

        if rules[:presence] == "1" || answer.answer_text.present?
          begin  DateTime.strptime(answer.answer_text.to_s, '%m/%d/%Y')
          rescue ArgumentError => e
            answer.errors.add(:answer_text, :invalid)
          end
        end
      end
    end
  end
end
