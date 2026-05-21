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
    rescue IOError, ActionController::Live::ClientDisconnected, SignalException
    ensure
      CLIENTS.delete(sse)
      sse.close
    end

  # ── Ingest endpoint (audio = local filesystem path) ─────────────
  def create
    audio = params[:audio]
    name  = params[:listener_name]

    return render json: { error: "Missing params" }, status: 422 unless audio && name.present?

    msg = Message.create!(listener_name: name, audio_filename: "pending", status: "pending")

    filename = "#{msg.id}.wav"
    dest = AudioStorage::DIR.join(filename)
    FileUtils.mkdir_p(AudioStorage::DIR)
    FileUtils.cp(audio.tempfile.path, dest)

    msg.update!(audio_filename: filename)

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
