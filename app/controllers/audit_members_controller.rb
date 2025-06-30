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

        render turbo_stream: [
          turbo_stream.replace("sortable-table", partial: "audits/team_members_table"),
          turbo_stream.replace("audit-stats", partial: "audits/audit_stats", locals: { 
            team_members: @team_members, 
            audit_session: @audit_session, 
            progress: @progress 
          })
        ]
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
end
