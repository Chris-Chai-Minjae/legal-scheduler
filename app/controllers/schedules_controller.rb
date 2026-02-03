# @TASK T4.2 - Schedules List Page Controller
# @SPEC REQ-DASH-02: Status filtering, pagination, detail view

class SchedulesController < ApplicationController
  layout "dashboard"

  before_action :resume_session
  before_action :set_schedule, only: [:show, :edit, :update, :destroy, :cancel]

  # GET /schedules
  # Displays schedule list with filtering and pagination
  def index
    @calendars = Current.user.calendars
    @current_status = params[:status]&.to_sym || :all

    # Base query: user's schedules through calendars
    @schedules = Schedule
      .joins(:calendar)
      .where(calendars: { user_id: Current.user.id })
      .order(scheduled_date: :asc)

    # Apply status filter
    case @current_status
    when :pending
      @schedules = @schedules.pending_approval
    when :approved
      @schedules = @schedules.approved
    when :rejected
      @schedules = @schedules.rejected
    when :cancelled
      @schedules = @schedules.cancelled
    when :synced
      @schedules = @schedules.where(status: :synced)
    end

    # Apply search filter if present
    if params[:q].present?
      query = "%#{params[:q]}%"
      @schedules = @schedules.where("title LIKE ? OR description LIKE ?", query, query)
    end

    # Paginate results (20 per page using kaminari-like API)
    @schedules = @schedules.page(params[:page]).per(20)

    # Count for each status (for tab badges)
    all_schedules = Schedule.joins(:calendar).where(calendars: { user_id: Current.user.id })
    @status_counts = {
      all: all_schedules.count,
      pending: all_schedules.pending_approval.count,
      approved: all_schedules.approved.count,
      rejected: all_schedules.rejected.count,
      synced: all_schedules.where(status: :synced).count,
      cancelled: all_schedules.cancelled.count
    }
  end

  # POST /schedules/sync
  # Google Calendar와 DB 동기화 (삭제된 이벤트 감지)
  def sync
    SyncDeletedEventsJob.perform_later(Current.user.id)
    redirect_to schedules_path, notice: "동기화가 시작되었습니다. 잠시 후 확인해주세요."
  end

  # DELETE /schedules/:id
  # 수동으로 일정 취소
  def cancel
    @schedule.cancel!
    redirect_to schedules_path, notice: "일정이 취소되었습니다."
  end

  # GET /schedules/:id
  # Displays detailed schedule information
  def show
    @calendar = @schedule.calendar
  end

  # GET /schedules/:id/edit
  def edit
    @calendar = @schedule.calendar
  end

  # PATCH/PUT /schedules/:id
  def update
    if @schedule.update(schedule_params)
      redirect_to schedule_path(@schedule), notice: "일정이 수정되었습니다."
    else
      @calendar = @schedule.calendar
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /schedules/:id
  def destroy
    @schedule.destroy
    redirect_to schedules_path, notice: "일정이 삭제되었습니다."
  end

  private

  def set_schedule
    @schedule = Schedule
      .joins(:calendar)
      .where(calendars: { user_id: Current.user.id })
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to schedules_path, alert: "일정을 찾을 수 없습니다."
  end

  def schedule_params
    params.require(:schedule).permit(:title, :scheduled_date, :case_number, :case_name)
  end
end
