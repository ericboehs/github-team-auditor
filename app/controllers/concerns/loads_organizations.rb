# frozen_string_literal: true

module LoadsOrganizations
  extend ActiveSupport::Concern

  private

  def load_organizations
    @organizations = Organization.all
  end
end
