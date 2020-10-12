module Rapidfire
  class AttemptsController < Rapidfire::ApplicationController
    if Rails::VERSION::MAJOR ==  5
      before_action :find_survey!
      before_action :check_resubmit_availability, only: [:create]
    else
      before_filter :find_survey!
      before_filter :check_resubmit_availability, only: [:create]
    end

    def new
      @attempt_builder = AttemptBuilder.new(attempt_params)
      @admin_layout = false
    end

    def create
      @attempt_builder = AttemptBuilder.new(attempt_params)

      respond_to do |format|
        if @attempt_builder.save
          format.js { render "rapidfire/attempts/success" }
          format.json { render json: {}, status: :ok }
          format.html { redirect_to after_answer_path_for }
        else
          error_message = 'survey_incomplete_message'.cms {'Please fill the Survey.'}
          format.js {render js: "toastr.error('#{error_message}');"}
          format.json do
            errors = {}
            @attempt_builder.answers.each do |answer|
              msg = answer.errors.try(:[], :answer_text).try(:first)
              next if msg.blank?
              errors["#{answer.question_id}"] = msg
            end
            render json: {errors: errors}, status: :unprocessable_entity
          end
          format.html { render :new }
        end
      end
    end

    def show
      @attempt_answers = Rapidfire::Answer.where(attempt_id: params[:id])
      @survey_questions = Rapidfire::Question.where(survey_id: params[:survey_id])
      @admin_layout = false
    end

    def edit
      @attempt_builder = AttemptBuilder.new(attempt_params)
      @admin_layout = false
    end

    def update
      @attempt_builder = AttemptBuilder.new(attempt_params)

      if @attempt_builder.save
        redirect_to surveys_path
      else
        render :edit
      end
    end

    private

    def check_resubmit_availability
      attempted_survey = Rapidfire::Attempt.where(user_id: current_user.id, survey_id: params[:survey_id]).last
      if attempted_survey.present?
        if PyrCore::AppSetting.enable_survey_resubmission != "true"
          respond_to do |format|
            format.js { render "rapidfire/attempts/submitted" }
          end
        end
      end
    end

    def find_survey!
      @survey = Survey.find(params[:survey_id])
    end

    def attempt_params
      answer_params = { params: (params[:attempt] || {}) }
      answer_params.merge(user: current_user, survey: @survey, attempt_id: params[:id])
    end

    # Override path to redirect after answer the survey
    # Write:
    #   # my_app/app/decorators/controllers/rapidfire/answer_groups_controller_decorator.rb
    #   Rapidfire::AnswerGroupsController.class_eval do
    #     def after_answer_path_for
    #       main_app.root_path
    #     end
    #   end
    def after_answer_path_for
      surveys_path
    end

    def rapidfire_current_scoped
      send 'current_'+scoped.to_s
    end
  end
end
