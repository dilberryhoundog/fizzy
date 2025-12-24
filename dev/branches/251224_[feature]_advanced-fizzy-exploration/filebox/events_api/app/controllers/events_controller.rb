# Proposed replacement for app/controllers/events_controller.rb
# Extends existing controller with JSON API support

class EventsController < ApplicationController
  include DayTimelinesScoped

  def index
    respond_to do |format|
      format.html { fresh_when @day_timeline }
      format.json { render_json_index }
    end
  end

  private
    def render_json_index
      set_page_and_extract_portion_from filtered_events
    end

    def filtered_events
      events = Current.user.accessible_events.order(created_at: :desc).preloaded

      events = events.where(board_id: params[:board_ids]) if params[:board_ids].present?
      events = events.where(action: params[:actions]) if params[:actions].present?
      events = events.where(action: params[:action]) if params[:action].present?
      events = events.where(creator_id: params[:creator_ids]) if params[:creator_ids].present?
      events = events.where("created_at >= ?", Time.parse(params[:since])) if params[:since].present?
      events = events.where("created_at <= ?", Time.parse(params[:until])) if params[:until].present?

      # Card filtering (for Card eventables only)
      if params[:card_ids].present?
        events = events.where(eventable_type: "Card", eventable_id: params[:card_ids])
      end

      events
    end
end
