# @TASK T4.1 - Dashboard controller for main dashboard
# @SPEC .sdd/specs/dashboard/spec.md#REQ-DASH-01

class DashboardController < ApplicationController
  def index
    @user = Current.session.user

    # 통계 계산 (REQ-DASH-01)
    @pending_count = @user.schedules.pending_approval.count
    @this_week_count = schedules_this_week.count
    @this_month_approved = @user.schedules.approved
                                .where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
                                .count

    # 대기중 일정 목록
    @pending_schedules = @user.schedules
                              .pending_approval
                              .includes(:calendar)
                              .order(scheduled_date: :asc)
  end

  private

  def schedules_this_week
    week_start = Time.current.beginning_of_week
    week_end = Time.current.end_of_week

    Current.session.user.schedules
      .where(scheduled_date: week_start..week_end)
  end
end
