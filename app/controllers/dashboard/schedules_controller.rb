# @TASK T4.1 - Dashboard schedules controller for approve/reject actions
# @SPEC .sdd/specs/dashboard/spec.md#REQ-DASH-01

class Dashboard::SchedulesController < ApplicationController
  def approve
    @schedule = Current.session.user.schedules.find(params[:id])

    if @schedule.approve!
      # Google Calendar에 일정 등록 (비동기)
      CalendarSyncJob.perform_later(@schedule.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: "일정이 승인되었습니다. 캘린더에 등록 중..." }
      end
    else
      redirect_to dashboard_path, alert: "일정 승인에 실패했습니다."
    end
  end

  def reject
    @schedule = Current.session.user.schedules.find(params[:id])

    if @schedule.reject!
      # Telegram 알림 발송 (연결된 경우)
      if Current.user.telegram_chat_id.present?
        TelegramNotificationJob.perform_later(@schedule.id, :rejected)
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: "일정이 거부되었습니다." }
      end
    else
      redirect_to dashboard_path, alert: "일정 거부에 실패했습니다."
    end
  end
end
