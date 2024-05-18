Geocoder.configure(
  # street address geocoding service (default :nominatim)
  # lookup: :google,
  lookup: :mapbox,

  api_key: ENV['MAPBOX_GEOCODER_API_KEY'] ? ENV['MAPBOX_GEOCODER_API_KEY'] : '',

  # api_key: ENV['GOOGLE_MAPS_API_KEY'] ? ENV['GOOGLE_MAPS_API_KEY'] : '',

  # geocoding service request timeout, in seconds (default 3):
  timeout: 20,
  use_https: true,
  language: :en,
  logger: Rails.logger,
  kernel_logger_level: ::Logger::DEBUG
)
