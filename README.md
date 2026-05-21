# README Radio DJ — Audio Transcription PoC

A mini Rails application that lets radio listeners send audio messages to a DJ dashboard, with real-time transcription via OpenAI Whisper.

---

## Architecture

### Context

Radio listeners are in constant contact with their favourite DJs via the station's app. They send text messages, photos, and audio or video clips. Speed is essential for the DJ: they need to see incoming messages at a glance, with audio messages transcribed automatically so they don't have to listen to everything live.

---

### Part 1 — User Interface (App side)

The listener flow is intentionally linear:

1. Open the app and enter a display name (or use a stored profile)
2. Choose a message type: text, photo, or audio/video
3. For audio: tap to record, or attach an existing file
4. Send — the app shows an optimistic "sent" state immediately
5. Confirmation arrives via the same SSE channel as the DJ dashboard

The key UX decision is to keep the recording gesture as fast as possible — one tap to record, one tap to send. No forms, no friction.

---

### Part 2 — Backend Architecture

```
┌─────────────────┐        multipart/form-data        ┌──────────────────────────────────────┐
│                 │ ──────────────────────────────────▶│                                      │
│  Listener App   │                                    │           Rails API                  │
│  iOS · Android  │                                    │   POST /messages                     │
│                 │                                    │   • validates params                 │
└─────────────────┘                                    │   • stores audio → tmp/audio/        │
                                                       │   • creates Message (status:pending) │
                                                       │   • enqueues TranscribeJob           │
                                                       │   • SSE push #1 → DJ dashboard       │
                                                       └──────────────┬───────────────────────┘
                                                                      │
                                                         ┌────────────▼────────────┐
                                                         │       Storage           │
                                                         │  SQLite (dev)           │
                                                         │  PostgreSQL (prod)      │
                                                         │  S3 / local (audio)     │
                                                         └────────────┬────────────┘
                                                                      │
                                                         ┌────────────▼────────────┐
                                                         │   Sidekiq Worker        │
                                                         │   TranscribeJob         │
                                                         │   • reads audio file    │
                                                         │   • calls Whisper API   │
                                                         │   • updates Message     │
                                                         │     (status: done)      │
                                                         │   • SSE push #2 →       │
                                                         │     DJ dashboard        │
                                                         └────────────┬────────────┘
                                                                      │
                                                         ┌────────────▼────────────┐
                                                         │     OpenAI Whisper      │
                                                         │     audio → text        │
                                                         └─────────────────────────┘
```

**Two SSE pushes to the DJ dashboard:**

| Push | Timing | Payload |
|------|--------|---------|
| #1 | Immediate (< 200ms) | `{ status: "pending", listener_name: "..." }` |
| #2 | After transcription (~1–5s) | `{ status: "done", transcription: "..." }` |

This ensures the DJ sees the message arrive instantly — even before transcription is complete — and the text appears in place once ready.

**Scalability considerations (production):**
- Replace SQLite with PostgreSQL
- Replace `tmp/audio/` with S3 (Active Storage)
- Replace AsyncAdapter with Sidekiq + Redis for job resilience
- Multiple Rails instances behind a load balancer — SSE clients need sticky sessions or a shared pub/sub layer (Redis pub/sub or Action Cable)

---

### Part 3 — DJ & Studio Dashboard

The dashboard is a single live page connected via **Server-Sent Events (SSE)**. No polling, no page refresh.

**Message lifecycle in the UI:**

```
[incoming]  → Jones        🟡 transcribing...
             ──────────────────────────────
[updated]   → Jones        🟢 done
               "Super émission ce soir !"
```

Each message renders immediately with a `pending` badge. When the transcription arrives, the card updates in place (upsert by message ID) — no jump, no flicker.

**What if transcription takes too long?**

The DJ sees the message and the listener's name right away. They can choose to play the audio clip directly while waiting. The transcription fills in when it's ready. In production, a timeout threshold (e.g. 10s) could trigger a "transcription unavailable" fallback state.

---

## PoC — Getting Started

### Requirements

- Ruby 3.4+
- Rails 8.1
- An OpenAI API key (Whisper access)

### Setup

```bash
git clone <repo>
cd radio-dj
bundle install
rails db:migrate
mkdir -p tmp/audio
```

### Configuration

Create a `.env` file at the root (never commit this):

```
OPENAI_API_KEY=sk-proj-...
```

### Run

```bash
rails server
```

Open [http://localhost:3000](http://localhost:3000) for the DJ dashboard.

### Send an audio message

```bash
curl -X POST http://localhost:3000/messages \
  -F "listener_name=Jonas" \
  -F "audio=@/path/to/your/file.wav"
```

### Run tests

```bash
rails test
```

---

## Project Structure

```
app/
  controllers/
    messages_controller.rb   # upload endpoint + SSE stream + DJ dashboard
  jobs/
    transcribe_job.rb        # async Whisper transcription
  models/
    message.rb               # listener_name, audio_filename, transcription, status
  views/
    messages/
      dashboard.html.erb     # DJ live view (SSE + upsert)
config/
  initializers/
    openai.rb                # OpenAI client configuration
test/
  controllers/
  jobs/
  models/
```

---

## Technical Choices

| Decision | Choice | Why |
|----------|--------|-----|
| Real-time | SSE (Server-Sent Events) | Unidirectional push, no WebSocket overhead |
| Background jobs | ActiveJob + AsyncAdapter | Zero config for PoC; swap to Sidekiq in prod |
| Transcription | OpenAI Whisper | Industry standard, simple SDK |
| Storage | SQLite + local filesystem | Sufficient for PoC; S3 + PostgreSQL in prod |
| Auth | None | Out of scope for this PoC |