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

    def answered_users
      @users = User.find(Rapidfire::Attempt.find(Rapidfire::Question.find(params[:question_id]).answers.where(answer_text: params[:answer_text]).pluck(:attempt_id)).map(&:user_id))
      respond_to do |format|
        format.js
      end
    end

    def results
      @survey = Survey.find(params[:id])
      respond_to do |format|
        format.json {
          @survey_results = SurveyResults.new(survey: @survey).extract 
          render json: @survey_results, root: false 
        }
        format.html {
          # params={market_filter: 2, attempt_from:'02/01/2020', attempt_to:'02/01/2021', id: 1}

          market_condition = params[:market_filter].present? ? " and u.market_id=#{params[:market_filter]}" : ''
          attempt_from_date_condition = params[:attempt_from].present? ? " and a.updated_at >= '#{params[:attempt_from].to_date.strftime('%F')}'" : ''
          attempt_to_date_condition = params[:attempt_to].present? ? " and a.updated_at < '#{params[:attempt_to].to_date.strftime('%F')}'" : ''
          query = <<-SQL
            select s.id 'survey_id', q.id 'question_id', q.question_text 'question', q.type 'question_type', 
            a.answer_text 'answer', u.consultant_id 'consultant_id', u.username 'username' 
            from rapidfire_surveys s, rapidfire_questions q, rapidfire_answers a, rapidfire_attempts t, users u
            where t.survey_id=s.id and t.id=a.attempt_id and t.user_id=u.id
            #{market_condition}#{attempt_from_date_condition}#{attempt_to_date_condition}
            and s.id=#{params[:id]} and q.id= a.question_id and q.survey_id=s.id
            -- group by s.id, q.id, a.answer_text
            order by s.id, q.position,  a.answer_text asc
          SQL
          results = ActiveRecord::Base.connection.exec_query(query).to_a
          questions = {}
          prev_question_id = nil
          prev_question_type = nil
          answers_array = []
          answers_hash = {}
          answered_users = []
          results.each_with_index do |r, i|
            options = if ['Rapidfire::Questions::Short', 'Rapidfire::Questions::Date', 'Rapidfire::Questions::Long', 'Rapidfire::Questions::Numeric'].include? r['question_type']
              false
            elsif ['Rapidfire::Questions::Select', 'Rapidfire::Questions::Radio', 'Rapidfire::Questions::Checkbox'].include? r['question_type']
              true
            end
            # puts "r['question_id']::: #{r['question_id']}, r['question_type']::::#{r['question_type']}, options ::: #{options}, index #{i}, same:::#{(questions.keys.include? r['question_id'])}"
            #end
            unless questions.keys.include? r['question_id']
              questions[r['question_id']] = {'question' => r['question']} unless questions.keys.include? r['question_id']
              if i != 0
                puts "questions::: #{questions}"
                puts "prev_question_id:::#{prev_question_id}, questions[r['prev_question_id']]::::#{questions[r['prev_question_id']]}"
                if prev_question_type
                  questions[prev_question_id] = questions[prev_question_id].merge({answers: answers_hash})
                else
                  questions[prev_question_id] = questions[prev_question_id].merge({answers: answers_array})
                end
                answers_array = []
                answers_hash = {}
                answered_users = []
                answered_users_hash = {}
              end
            end
            if options
              puts  "answers_hash::::#{answers_hash}, r['answer']::#{r['answer']}, answers_hash[r['answer']][users]:::#{answers_hash[r['answer']]}"
              if answers_hash[r['answer']]
                count = answers_hash[r['answer']][:count] || 0
                answers_hash[r['answer']][:count] = count+1
                answers_hash[r['answer']][:users] << r['consultant_id']||r['username']
              else
                answers_hash[r['answer']] = {answer: r['answer'], count: 1, users: [r['consultant_id']||r['username']]}
              end
            else
              answers_array << {answer: r['answer'], user: r['consultant_id']||r['username']}
            end
            prev_question_id = r['question_id']
            prev_question_type = options
            prev_answer = r['answer']
          end
          @survey_results = questions
        }
        format.js
        format.csv {
          @survey_results = SurveyResults.new(survey: @survey).extract
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
              user = attempt.user
              user_consultant_id = user.consultant_id.present? ? "ID#{user.consultant_id}" : user.display_name 
              user_info = "#{user_consultant_id}, #{user.display_name}, #{user.email}, #{attempt.created_at.strftime("%B %d, %Y %H:%M:%S")}"
              record = [user_info]
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
