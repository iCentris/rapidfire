module Rapidfire
  class SurveysController < Rapidfire::ApplicationController
    if Rails::VERSION::MAJOR == 5
      before_action :authenticate_administrator!, except: [:index, :results]
    else
      before_filter :authenticate_administrator!, except: [:index, :results]
    end

    def index
      if can_administer?
        @surveys = if defined?(Kaminari)
          Rapidfire::Survey.page(params[:page])
        else
          Rapidfire::Survey.all
        end
      else
        @surveys = if defined?(Kaminari)
          Rapidfire::Survey.joins(:attempts).where("rapidfire_attempts.user_id = ?", current_user.id).page(params[:page])
        else
          Rapidfire::Survey.joins(:attempts).where("rapidfire_attempts.user_id = ?", current_user.id).all
        end
        @admin_layout = false
      end
    end

    def new
      @survey = Survey.new
    end

    def create
      @survey = Survey.new(survey_params)
      if @survey.save
        respond_to do |format|
          format.html { redirect_to surveys_path }
          format.js
        end
      else
        respond_to do |format|
          format.html { render :new }
          format.js
        end
      end
    end

    def destroy
      @survey = Survey.find(params[:id])
      @survey.destroy

      respond_to do |format|
        format.html { redirect_to surveys_path }
        format.js
      end
    end

    def results
      @survey = Survey.find(params[:id])
      @survey_results =
        SurveyResults.new(survey: @survey).extract

      respond_to do |format|
        format.json { render json: @survey_results, root: false }
        format.html
        format.js
        format.csv {
          questions = @survey.questions
          question_ids = questions.pluck(:id)
          attempts = @survey.attempts
          headers = ["Consultant"]
          questions.each do |q|
            headers << q.question_text
          end
          export_csv = CSV.generate(headers: true) do |csv|
            csv << headers
            attempts.find_each(batch_size: 100) do |attempt|
              
            answers_hash = {}
            attempt.answers.each do |answer|
              answers_hash[answer.question_id] = answer.answer_text
            end
              record = [attempt.user.consultant_id || attempt.user.display_name]
              question_ids.each do |question_id|
                record << answers_hash[question_id]
              end
              csv << record
            end
          end
          send_data export_csv, 
              type: 'text/csv',
              disposition: 'attachment',
              filename: "#{@survey.name}-results-#{Time.now.strftime('%m/%d/%Y')}.csv"
        }
      end
    end

    def export
      @objects = if params[:id]
                 [Rapidfire::Survey.find(params[:id])]
               else
                 Rapidfire::Survey.all
               end

      respond_to do |format|
        format.html{}
      end
    end

  def import
  end

  def create_import
    data   = params.require("import")["data"].to_s
    survey  = YAML.load(data)
    questions=survey.delete(:questions)
    survey = Rapidfire::Survey.create(survey)
    survey.questions << Rapidfire::Question.create(questions)
    survey.save
    if survey.errors.empty?
      flash[:success] = action_cms("success", "Survey imported successfully.")
      respond_to do |format|
        format.html { redirect_to({ action: :index }) }
      end
    else
      flash[:alert] = action_cms("invalid", errors: survey.errors.full_messages.join("|")) {"Could not import survey. %{errors}"}
      respond_to do |format|
        format.html { redirect_to({ action: :import }) }
      end
    end
  end


    private

    def survey_params
      if Rails::VERSION::MAJOR >= 4
        params.require(:survey).permit(:name, :introduction)
      else
        params[:survey]
      end
    end
  end
end
