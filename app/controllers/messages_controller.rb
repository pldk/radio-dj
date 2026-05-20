class MessagesController < ApplicationController
  include ActionController::Live

  CLIENTS = Concurrent::Array.new

  skip_before_action :verify_authenticity_token, only: :create

  # ── DJ dashboard ──────────────────────────────────────────────
  def dashboard
    @messages = Message.order(created_at: :desc).limit(50)
  end

  # ── SSE stream ────────────────────────────────────────────────
  def stream
    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = SSE.new(response.stream, retry: 300)
    CLIENTS << sse

    loop { sleep 15; sse.write(nil, event: "ping") }
  rescue IOError, ActionController::Live::ClientDisconnected
  ensure
    CLIENTS.delete(sse)
    sse.close
  end

  # ── Ingest endpoint (audio = local filesystem path) ─────────────
  def create
    audio_path = params[:audio].to_s.strip
    name       = params[:listener_name]

    return render json: { error: "Missing params" }, status: 422 unless audio_path.present? && name.present?

    src = Pathname(File.expand_path(audio_path, Dir.home))
    return render json: { error: "Audio file not found" }, status: 422 unless src.file?

    dest_dir = Rails.root.join("tmp", "audio")
    FileUtils.mkdir_p(dest_dir)

    filename = "#{SecureRandom.hex(8)}#{src.extname}"
    dest = dest_dir.join(filename)
    FileUtils.cp(src, dest)

    msg = Message.create!(listener_name: name, audio_filename: filename, status: "pending")

    self.class.broadcast(msg)
    TranscribeJob.perform_later(msg.id)

    render json: msg.as_event, status: :created
  end

  # ── Broadcast to all connected SSE clients ────────────────────
  def self.broadcast(msg)
    dead = []
    CLIENTS.each do |client|
      client.write(msg.as_event.to_json, event: "message")
    rescue
      dead << client
    end
    dead.each { |client| CLIENTS.delete(client) }
  end
end