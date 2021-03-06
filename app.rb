require 'rack/parser'
require 'sinatra'
require 'json'
require 'faraday'

# Required
set :lifx_access_token, ENV['LIFX_ACCESS_TOKEN'] || raise("no LIFX_ACCESS_TOKEN set")
set :bulb_selector,     ENV['BULB_SELECTOR']     || raise("no BULB_SELECTOR set")
set :webhook_token,     ENV['WEBHOOK_TOKEN']     || raise("no WEBHOOK_TOKEN set")

# Optional
set :lifx_api_host, ENV['LIFX_ENDPOINT'] || 'api.lifx.com'

use Rack::Parser # loads the JSON request body into params

helpers do
  def lifx_api
    Faraday.new(url: "https://#{settings.lifx_api_host}") do |faraday|
      faraday.authorization :Bearer, settings.lifx_access_token
      faraday.request :url_encoded
      # faraday.response :logger
      faraday.adapter Faraday.default_adapter
      faraday.use Faraday::Response::RaiseError
    end
  end
end

post "/" do
  halt 401 unless request.env['HTTP_X_BUILDKITE_TOKEN'] == settings.webhook_token

  puts params.inspect # helpful for inspecting incoming webhook requests

  buildkite_event = request.env['HTTP_X_BUILDKITE_EVENT']

  if buildkite_event == 'build.running'
    lifx_api.post "/v1/lights/#{settings.bulb_selector}/effects/breathe.json",
      power_on:   false,
      color:      "yellow brightness:5%",
      from_color: "yellow brightness:35%",
      period:     5,
      cycles:     9999,
      persist:    true
  end

  if buildkite_event == 'build.finished'
    if params['build']['state'] == 'passed' && params['build']['state'] != 'canceled'
      lifx_api.post "/v1/lights/#{settings.bulb_selector}/effects/breathe.json",
        power_on:   true,
        color:      "green brightness:55%",
        from_color: "green brightness:30%",
        period:     1,
        cycles:     3,
        persist:    true,
        peak:       0.2
    else
      lifx_api.post "/v1/lights/#{settings.bulb_selector}/effects/breathe.json",
        power_on:   true,
        color:      "red brightness:60%",
        from_color: "red brightness:25%",
        period:     0.1,
        cycles:     20,
        persist:    true,
        peak:       0.2
    end
  end

  status 200
end

get "/" do
  "<div style=\"font:24px Avenir,Helvetica;max-width:32em;margin:2em;line-height:1.3\"><h1 style=\"font-size:1.5em\">Huzzah! You’re almost there.</h1><p style=\"color:#666\">Now create a webhook in your <a href=\"https://buildkite.com/\" style=\"color:black\">Buildkite</a> notification settings with this URL, and the webhook token from the Heroku app’s config&nbsp;variables.</p><p>#{request.scheme}://#{request.host}/</p></div>"
end
