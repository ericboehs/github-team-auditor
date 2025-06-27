module Sortable
  extend ActiveSupport::Concern

  private

  def sort_column
    params[:sort].presence
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end
