class AuditMembersController < ApplicationController
  before_action :set_audit_member, only: [ :toggle_status ]

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

  private

  def set_audit_member
    @audit_member = AuditMember.find(params[:id])
  end
end
