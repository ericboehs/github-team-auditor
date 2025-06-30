module Sortable
  extend ActiveSupport::Concern

  # Public methods accessible to helpers via delegation
  def sort_column
    params[:sort].presence
  end

  def sort_direction
    # Validate sort direction to prevent SQL injection
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

  def effective_sort_column_for_team_members
    sort_column || "github"
  end

  private

  def apply_team_member_sorting(relation)
    case effective_sort_column_for_team_members
    when "github"
      relation.order(team_members: { github_login: sort_direction })
    when "member"
      relation.order(team_members: { github_login: sort_direction })
    when "role"
      direction = sort_direction == "asc" ? :desc : :asc
      relation.order(team_members: { maintainer_role: direction })
    when "status"
      relation.order(audit_members: { access_validated: sort_direction })
    when "first_seen"
      # Sort by minimum issue_created_at from issue_correlations using subquery
      direction = sort_direction == "asc" ? "ASC" : "DESC"
      nulls_position = sort_direction == "asc" ? "NULLS FIRST" : "NULLS LAST"

      relation.joins(
        "LEFT JOIN (
          SELECT team_member_id, MIN(issue_created_at) as first_seen_at
          FROM issue_correlations
          GROUP BY team_member_id
        ) ic_first_agg ON ic_first_agg.team_member_id = team_members.id"
      ).order(Arel.sql("ic_first_agg.first_seen_at #{direction} #{nulls_position}"))

    when "last_seen"
      # Sort by maximum issue_updated_at from issue_correlations using subquery
      direction = sort_direction == "asc" ? "ASC" : "DESC"
      nulls_position = sort_direction == "asc" ? "NULLS FIRST" : "NULLS LAST"

      relation.joins(
        "LEFT JOIN (
          SELECT team_member_id, MAX(issue_updated_at) as last_seen_at
          FROM issue_correlations
          GROUP BY team_member_id
        ) ic_last_agg ON ic_last_agg.team_member_id = team_members.id"
      ).order(Arel.sql("ic_last_agg.last_seen_at #{direction} #{nulls_position}"))
    when "comment"
      # Sort by comments/notes - empty comments first when ascending
      direction = sort_direction == "asc" ? "ASC" : "DESC"
      nulls_position = sort_direction == "asc" ? "NULLS FIRST" : "NULLS LAST"

      # Use COALESCE to treat empty strings as NULL for proper sorting
      relation.order(Arel.sql("COALESCE(NULLIF(TRIM(audit_members.notes), ''), NULL) #{direction} #{nulls_position}"))
    when "issue"
      # Sort by first (lowest/earliest) GitHub issue number
      direction = sort_direction == "asc" ? "ASC" : "DESC"
      nulls_position = sort_direction == "asc" ? "NULLS FIRST" : "NULLS LAST"

      relation.joins(
        "LEFT JOIN (
          SELECT team_member_id, MIN(github_issue_number) as first_issue_number
          FROM issue_correlations
          GROUP BY team_member_id
        ) ic_issue_agg ON ic_issue_agg.team_member_id = team_members.id"
      ).order(Arel.sql("ic_issue_agg.first_issue_number #{direction} #{nulls_position}"))
    else
      # Default sorting
      relation.order(team_members: { github_login: :asc })
    end
  end
end
