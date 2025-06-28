class AuditMembersController < ApplicationController
  include Sortable

  before_action :set_audit_member, only: [ :toggle_status, :update ]

  def toggle_status
    if @audit_member.removed?
      # removed → pending: reset to pending state
      @audit_member.update!(removed: false, access_validated: nil)
    elsif @audit_member.validation_status == "validated"
      # validated → removed
      @audit_member.update!(removed: true)
    else
      # pending → validated
      @audit_member.update!(access_validated: true)
    end

    respond_to do |format|
      format.turbo_stream do
        # Re-fetch the sorted team members for the audit session
        @audit_session = @audit_member.audit_session
        @team_members = @audit_session
          .audit_members
          .includes(:audit_notes, :team_member)
          .joins(:team_member)

        # Apply the same sorting logic as the show action
        @team_members = apply_team_member_sorting(@team_members)

        # Calculate progress for stats update
        @progress = @audit_session.progress_percentage

        render turbo_stream: turbo_stream.replace("sortable-table", partial: "audits/team_members_table")
      end
      format.html { redirect_to audit_path(@audit_member.audit_session, sort: params[:sort], direction: params[:direction]) }
    end
  end

  def update
    # Track notes metadata if notes are being updated
    if audit_member_params[:notes] && audit_member_params[:notes] != @audit_member.notes
      @audit_member.notes_updated_by = Current.user
      @audit_member.notes_updated_at = Time.current
    end

    if @audit_member.update(audit_member_params)
      respond_to do |format|
        format.json { render json: { status: "success" } }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("notes_#{@audit_member.id}", partial: "audits/comment_cell", locals: { member: @audit_member }) }
      end
    else
      respond_to do |format|
        format.json { render json: { status: "error", errors: @audit_member.errors } }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("notes_#{@audit_member.id}", partial: "audits/comment_cell", locals: { member: @audit_member }) }
      end
    end
  end

  private

  def set_audit_member
    @audit_member = AuditMember.find(params[:id])
  end

  def audit_member_params
    params.require(:audit_member).permit(:comment, :notes)
  end

  def apply_team_member_sorting(relation)
    case sort_column
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
    else
      # Default sorting
      relation.order(team_members: { github_login: :asc })
    end
  end
end
