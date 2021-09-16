class HomeController < ApplicationController
  before_action :require_user, only: %w(profile update_profile)
  before_action :require_editor, only: %w(dashboard reviews incoming stats all in_progress)
  # layout "dashboard", only:  %w(dashboard reviews incoming stats all in_progress)

  def index
    @models = Model.unscoped.visible.order(accepted_at: :desc).limit(10)
  end

  def about
  end

  def dashboard
    if params[:editor]
      @editor = Editor.find_by_login(params[:editor])
    else
      @editor = current_user.editor
    end

    @reviewer = params[:reviewer].nil? ? "@arfon" : params[:reviewer]
    @reviewer_models = Model.unscoped.where(":reviewer = ANY(reviewers)", reviewer: @reviewer).group_by_month(:accepted_at).count

    @accepted_models = Model.unscoped.visible.group_by_month(:accepted_at).count
    @editor_models = Model.unscoped.where(editor: @editor).visible.group_by_month(:accepted_at).count

    @assignment_by_editor = Model.unscoped.in_progress.group(:editor_id).count
    @paused_by_editor = Model.unscoped.in_progress.where("labels->>'paused' ILIKE '%'").group(:editor_id).count

    @models_last_week = Model.unscoped.visible.since(1.week.ago).group(:editor_id).count
    @models_last_month = Model.unscoped.visible.since(1.month.ago).group(:editor_id).count
    @models_last_3_months = Model.unscoped.visible.since(3.months.ago).group(:editor_id).count
    @models_last_year = Model.unscoped.visible.since(1.year.ago).group(:editor_id).count
    @models_all_time = Model.unscoped.visible.since(100.year.ago).group(:editor_id).count
  end

  def incoming
    sort = "complete"
    case params[:order]
    when "complete-desc"
      @order = "desc"
    when "complete-asc"
      @order = "asc"
    when "active-desc"
      @order = "desc"
      sort = "active"
    when "active-asc"
      @order = "asc"
      sort = "active"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    if sort == "active"
      @models = Model.unscoped.in_progress.where(editor: nil).order(last_activity: @order).paginate(
                  page: params[:page],
                  per_page: 20
                )
    else
      @models = Model.in_progress.where(editor: nil).paginate(
        page: params[:page],
        per_page: 20
      )
    end

    load_pending_invitations_for_models(@models)

    @editor = current_user.editor

    render template: "home/reviews"
  end

  def reviews
    sort = "complete"
    case params[:order]
    when "complete-desc"
      @order = "desc"
    when "complete-asc"
      @order = "asc"
    when "active-desc"
      @order = "desc"
      sort = "active"
    when "active-asc"
      @order = "asc"
      sort = "active"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    if params[:editor]
      @editor = Editor.find_by_login(params[:editor])

      if sort == "active"
        @models = Model.unscoped.in_progress.where(editor: @editor).order(last_activity: @order).paginate(
          page: params[:page],
          per_page: 20
        )
      else
        @models = Model.unscoped.in_progress.where(editor: @editor).order(percent_complete: @order).paginate(
          page: params[:page],
          per_page: 20
        )
      end
    else
      @models = Model.everything.paginate(
                  page: params[:page],
                  per_page: 20
                )
    end
  end

  def in_progress
    sort = "complete"
    case params[:order]
    when "complete-desc"
      @order = "desc"
    when "complete-asc"
      @order = "asc"
    when "active-desc"
      @order = "desc"
      sort = "active"
    when "active-asc"
      @order = "asc"
      sort = "active"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    @editor = current_user.editor

    if sort == "active"
      @models = Model.unscoped.in_progress.order(last_activity: @order).paginate(
        page: params[:page],
        per_page: 20
      )
    else
      @models = Model.unscoped.in_progress.order(percent_complete: @order).paginate(
        page: params[:page],
        per_page: 20
      )
    end

    load_pending_invitations_for_models(@models)

    render template: "home/reviews"
  end

  def all
    sort = "complete"
    case params[:order]
    when "complete-desc"
      @order = "desc"
    when "complete-asc"
      @order = "asc"
    when "active-desc"
      @order = "desc"
      sort = "active"
    when "active-asc"
      @order = "asc"
      sort = "active"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    @editor = current_user.editor

    if sort == "active"
      @models = Model.unscoped.all.order(last_activity: @order).paginate(
        page: params[:page],
        per_page: 20
      )
    else
      @models = Model.unscoped.all.order(percent_complete: @order).paginate(
        page: params[:page],
        per_page: 20
      )
    end

    load_pending_invitations_for_models(@models)

    render template: "home/reviews"
  end

  def update_profile
    check_github_username

    if current_user.update(user_params)
      redirect_back(notice: "Profile updated", fallback_location: root_path)
    end
  end

  def profile
    @user = current_user
  end

private

  def check_github_username
    if user_params.has_key?('github_username')
      if !user_params['github_username'].strip.start_with?('@')
        old = user_params['github_username']
        user_params['github_username'] = old.prepend('@')
      end
    end
  end

  def user_params
    params.require(:user).permit(:email, :github_username)
  end

  def load_pending_invitations_for_models(models)
    @pending_invitations = Invitation.includes(:editor).pending.where(model: models)
  end
end
