require "local-links-manager/export/bad_links_url_and_status_exporter"
require "local-links-manager/export/links_exporter"
require "local-links-manager/import/links"

class LocalAuthoritiesController < ApplicationController
  include LinkFilterHelper

  def index
    @authorities = LocalAuthority.order(broken_link_count: :desc)
    raise RuntimeError.new("Missing Data") if @authorities.empty?
  end

  def show
    @authority = LocalAuthorityPresenter.new(LocalAuthority.find_by!(slug: params[:local_authority_slug]))
    @link_filter = params[:filter]
    @services = @authority.provided_services.order("services.label ASC")
    @links = links_for_authority.group_by { |link| link.service.id }
    @link_count = links_for_authority.count
  end

  def download_links_csv
    @authority = LocalAuthority.find_by!(slug: params[:local_authority_slug])
    authority_name = @authority.name.parameterize.underscore
    data = LocalLinksManager::Export::LinksExporter.new.export_links(@authority.id, params)
    send_data data, filename: "#{authority_name}_links.csv"
  end

  def upload_links_csv
    authority = LocalAuthority.find_by!(slug: params[:local_authority_slug])

    if params[:csv]
      update_count = LocalLinksManager::Import::Links.new(authority).import_links(params[:csv].read)
      flash[:success] = "#{update_count} #{'link has'.pluralize(update_count)} been updated"
    else
      flash[:danger] = "A CSV file must be provided."
    end

    redirect_to local_authority_path(authority)
  end

  def bad_homepage_url_and_status_csv
    data = LocalLinksManager::Export::BadLinksUrlAndStatusExporter.local_authority_bad_homepage_url_and_status_csv
    send_data data, filename: "bad_homepage_url_status.csv"
  end

private

  def links_for_authority
    @links_for_authority ||= filtered_links(@authority.provided_service_links)
      .includes(%i[service interaction])
      .all
  end
end
