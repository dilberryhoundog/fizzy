class EventsController < ApplicationController
  include DayTimelinesScoped

  skip_before_action :set_day_timeline, :set_filter, :set_user_filtering, if: -> { request.format.json? }

  def index
    respond_to do |format|
      format.html { fresh_when @day_timeline }
      format.json do
        set_page_and_extract_portion_from filtered_events
        render :index
      end
    end
  end

  private
    def filtered_events
      board_ids = Current.user.boards.pluck(:id)
      events = Event.where(board_id: board_ids).order(created_at: :desc)

      events = events.where(board_id: params[:board_ids]) if params[:board_ids].present?
      events = events.where(action: params[:event_actions]) if params[:event_actions].present?
      events = events.where(action: params[:event_action]) if params[:event_action].present?
      events = events.where(creator_id: params[:creator_ids]) if params[:creator_ids].present?
      events = filter_by_time_range(events)
      events = events.where(eventable_type: "Card", eventable_id: params[:card_ids]) if params[:card_ids].present?

      events
    end

    def filter_by_time_range(events)
      events = events.where("events.created_at >= ?", Time.zone.parse(params[:since])) if params[:since].present?
      events = events.where("events.created_at <= ?", Time.zone.parse(params[:until])) if params[:until].present?
      events
    end
end
