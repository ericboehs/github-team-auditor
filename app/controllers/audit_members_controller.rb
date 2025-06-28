class AuditMembersController < ApplicationController
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

    redirect_to audit_path(@audit_member.audit_session)
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
