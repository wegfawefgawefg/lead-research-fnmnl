require "date"
require "json"
require "securerandom"
require "time"
require "sinatra/base"
require_relative "db"

module FnmnlDemo
  class Metrics
    def initialize
      @started_at = Time.now
      @requests = Hash.new(0)
      @lock = Mutex.new
    end

    def record(method, path, status, elapsed_ms)
      key = [method, route_bucket(path), status].join("|")
      @lock.synchronize do
        @requests[key] += 1
        @requests["latency_sum_ms"] += elapsed_ms
      end
    end

    def to_prometheus
      lines = ["# HELP app_uptime_seconds Process uptime.", "# TYPE app_uptime_seconds gauge", "app_uptime_seconds #{(Time.now - @started_at).round}"]
      @lock.synchronize do
        @requests.each do |key, value|
          next if key == "latency_sum_ms"
          method, route, status = key.split("|")
          lines << %(http_requests_total{method="#{method}",route="#{route}",status="#{status}"} #{value})
        end
        lines << "http_request_latency_sum_ms #{@requests["latency_sum_ms"].round(2)}"
      end
      lines.join("\n") + "\n"
    end

    private

    def route_bucket(path)
      path.gsub(%r{/\d+}, "/:id")
    end
  end

  class App < Sinatra::Base
    configure do
      set :metrics, Metrics.new
      set :show_exceptions, false
      set :raise_errors, false
      FnmnlDemo.migrate!
      FnmnlDemo.seed!
    end

    before do
      @request_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      headers "Access-Control-Allow-Origin" => ENV.fetch("CORS_ORIGIN", "*"),
              "Access-Control-Allow-Methods" => "GET,POST,OPTIONS",
              "Access-Control-Allow-Headers" => "Content-Type"
      content_type :json
    end

    after do
      elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @request_started_at) * 1000
      settings.metrics.record(request.request_method, request.path_info, response.status, elapsed_ms)
    end

    options "*" do
      204
    end

    get "/healthz" do
      { ok: true, service: "fnmnl-demo-api", request_id: request_id }.to_json
    end

    get "/readyz" do
      FnmnlDemo.db.fetch("select 1").first
      { ok: true, database: "reachable" }.to_json
    rescue StandardError => e
      status 503
      { ok: false, error: e.class.name }.to_json
    end

    get "/metrics" do
      content_type "text/plain"
      settings.metrics.to_prometheus
    end

    get "/api/catalog" do
      cache_control :public, max_age: 30, s_maxage: 120
      artists = FnmnlDemo.db[:artists].order(:name).all
      releases = FnmnlDemo.db[:releases].join(:artists, id: :artist_id)
        .select(Sequel[:releases][:id], Sequel[:releases][:title], :label, :release_date, Sequel[:artists][:name].as(:artist))
        .reverse_order(:release_date).all
      events = FnmnlDemo.db[:events].join(:artists, id: :headliner_id)
        .select(Sequel[:events][:id], Sequel[:events][:title], :city, :venue, :event_date, :capacity, Sequel[:artists][:name].as(:headliner))
        .order(:event_date).all
      { artists: artists, releases: releases, events: events, generated_at: Time.now.utc.iso8601 }.to_json
    end

    get "/api/artists/:id" do
      cache_control :public, max_age: 15, s_maxage: 60
      artist = FnmnlDemo.db[:artists][id: params[:id].to_i]
      halt 404, { error: "artist not found" }.to_json unless artist

      {
        artist: artist,
        releases: FnmnlDemo.db[:releases].where(artist_id: artist[:id]).reverse_order(:release_date).all,
        events: FnmnlDemo.db[:events].where(headliner_id: artist[:id]).order(:event_date).all
      }.to_json
    end

    post "/api/follows" do
      payload = JSON.parse(request.body.read)
      email = payload.fetch("email").to_s.strip.downcase
      artist_id = Integer(payload.fetch("artist_id"))
      halt 422, { error: "email is required" }.to_json if email.empty?
      halt 404, { error: "artist not found" }.to_json unless FnmnlDemo.db[:artists][id: artist_id]

      FnmnlDemo.db[:follows].insert_conflict(target: [:email, :artist_id], update: { created_at: Time.now })
        .insert(email: email, artist_id: artist_id, created_at: Time.now)
      status 201
      { ok: true, request_id: request_id }.to_json
    rescue JSON::ParserError, KeyError, ArgumentError
      status 400
      { error: "expected JSON body with email and artist_id" }.to_json
    end

    error do
      status 500
      { error: "internal server error", request_id: request_id }.to_json
    end

    private

    def request_id
      env["HTTP_CF_RAY"] || env["HTTP_X_REQUEST_ID"] || SecureRandom.hex(8)
    end
  end
end
