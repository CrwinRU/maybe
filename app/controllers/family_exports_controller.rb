class FamilyExportsController < ApplicationController
  include StreamExtensions

  before_action :require_admin
  before_action :set_export, only: [ :download ]

  def new
    # Modal view for initiating export
  end

  def create
    @export = Current.family.family_exports.create!
    FamilyDataExportJob.perform_later(@export)

    respond_to do |format|
      format.html { redirect_to settings_profile_path, notice: t(".started") }
      format.turbo_stream {
        stream_redirect_to settings_profile_path, notice: t(".started")
      }
    end
  end

  def index
    @exports = Current.family.family_exports.ordered.limit(10)
    render layout: false # For turbo frame
  end

  def download
    if @export.downloadable?
      redirect_to @export.export_file, allow_other_host: true
    else
      redirect_to settings_profile_path, alert: t(".not_ready")
    end
  end

  private

    def set_export
      @export = Current.family.family_exports.find(params[:id])
    end

    def require_admin
      unless Current.user.admin?
        redirect_to root_path, alert: t("family_exports.require_admin.access_denied")
      end
    end
end
