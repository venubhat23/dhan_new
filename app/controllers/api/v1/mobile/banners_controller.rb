class Api::V1::Mobile::BannersController < Api::V1::Mobile::BaseController
  # GET /api/v1/mobile/banners
  # Returns active banners for mobile app
  def index
    begin
      location = params[:location] || 'home'

      # Validate location parameter
      unless Banner.display_locations.keys.include?(location)
        return render_error("Invalid location. Valid options: #{Banner.display_locations.keys.join(', ')}")
      end

      # Fetch active banners for the specified location
      banners = Banner.active
                      .current
                      .by_location(location)
                      .ordered
                      .includes([banner_image_attachment: :blob])

      banner_data = banners.map do |banner|
        {
          id: banner.id,
          title: banner.title,
          description: banner.description,
          redirect_link: banner.redirect_link,
          display_location: banner.display_location,
          display_order: banner.display_order,
          image_url: banner.main_image_url,
          display_start_date: banner.display_start_date.strftime('%Y-%m-%d'),
          display_end_date: banner.display_end_date.strftime('%Y-%m-%d'),
          is_active: banner.active?,
          created_at: banner.created_at.strftime('%Y-%m-%d %H:%M:%S')
        }
      end

      render_success({ banners: banner_data, total_count: banner_data.length }, "Banners fetched successfully")

    rescue => e
      Rails.logger.error "Error fetching banners: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error("Failed to fetch banners", :internal_server_error)
    end
  end

  # GET /api/v1/mobile/banners/locations
  # Returns available banner locations
  def locations
    begin
      locations = Banner.display_locations.map do |key, value|
        {
          key: key,
          value: value,
          display_name: key.humanize
        }
      end

      render_success(locations, "Banner locations fetched successfully")

    rescue => e
      Rails.logger.error "Error fetching banner locations: #{e.message}"
      render_error("Failed to fetch banner locations", :internal_server_error)
    end
  end

  # GET /api/v1/mobile/banners/:id
  # Returns specific banner details
  def show
    begin
      banner = Banner.active.find(params[:id])

      # Check if banner is currently active
      unless banner.current?
        return render_error("Banner is not currently active", :not_found)
      end

      banner_data = {
        id: banner.id,
        title: banner.title,
        description: banner.description,
        redirect_link: banner.redirect_link,
        display_location: banner.display_location,
        display_location_text: banner.display_location_humanized,
        display_order: banner.display_order,
        image_url: banner.main_image_url,
        display_start_date: banner.display_start_date.strftime('%Y-%m-%d'),
        display_end_date: banner.display_end_date.strftime('%Y-%m-%d'),
        is_active: banner.active?,
        is_current: banner.current?,
        is_expired: banner.expired?,
        is_upcoming: banner.upcoming?,
        created_at: banner.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        updated_at: banner.updated_at.strftime('%Y-%m-%d %H:%M:%S')
      }

      render_success(banner_data, "Banner details fetched successfully")

    rescue ActiveRecord::RecordNotFound
      render_error("Banner not found", :not_found)
    rescue => e
      Rails.logger.error "Error fetching banner: #{e.message}"
      render_error("Failed to fetch banner details", :internal_server_error)
    end
  end

  # POST /api/v1/mobile/banners/:id/track_click
  # Track banner click analytics (optional feature)
  def track_click
    begin
      banner = Banner.active.find(params[:id])

      # You can implement click tracking logic here
      # For example, increment click count, log analytics, etc.
      Rails.logger.info "Banner #{banner.id} clicked by user"

      # Return the redirect link for the mobile app to navigate
      render_success(
        { redirect_link: banner.redirect_link },
        "Banner click tracked successfully"
      )

    rescue ActiveRecord::RecordNotFound
      render_error("Banner not found", :not_found)
    rescue => e
      Rails.logger.error "Error tracking banner click: #{e.message}"
      render_error("Failed to track banner click", :internal_server_error)
    end
  end

  private

  # Additional helper methods if needed
  def banner_params
    params.permit(:location)
  end
end