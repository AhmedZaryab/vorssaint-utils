# Spotify queue protocol: how unofficial clients reorder and edit the queue

Researched 2026-10-13. The public Web API has add-to-queue and read-queue, but no reorder and no remove. Every client that reorders does it the same way: it joins Spotify Connect as a device and sends a `set_queue` command carrying the whole upcoming list in the order it wants.

Sources are tagged **[S]** for Sapphire, our own legacy notch app (`/Users/zaryabahmed/Desktop/projects/Legacy-notch/Sapphire`, which already does this end to end), **[LR]** for librespot (Rust), **[GL]** for go-librespot, and **[SP]** for Spicetify. Claims with no tag are marked *unverified*.

S = `Sapphire/Services/Music/Spotify/SpotifyPrivateAPI.swift` (PrivateAPI), `.../SpotifyNetwork.swift` (Network), `Sapphire/Models/MusicModels.swift` (Models).

---

## 1. Transport

### 1.1 Token
- The web-player bearer comes from `GET https://open.spotify.com/api/token?reason=<init|transport>&productType=web-player&totp=<code>&totpVer=<n>&totpServer=<code>`, sent with the logged-in `sp_dc` cookie. [S] PrivateAPI:1670-1707.
- The TOTP is a 6-digit, 30-second code from a secret that Spotify rotates (`totpVer`). Sapphire tries the current window and the windows either side to absorb clock skew. [S] Network:851-950.
- History: the old `get_access_token` endpoint began failing with "Invalid TOTP" in March 2025, and the secret has rotated several times since. https://github.com/librespot-org/librespot/discussions/1562. The community secrets repo started returning 404 in Oct 2025: https://github.com/Viperinius/jellyfin-plugin-spotify-import/issues/74.

### 1.2 Dealer websocket
- URL: `wss://<dealer-host>/?access_token=<bearer>`. [GL] https://github.com/devgianlu/go-librespot/blob/master/dealer/dealer.go (`fmt.Sprintf("wss://%s/?access_token=%s", addr, accessToken)`). The host comes from apresolve (`gue1-dealer.spotify.com` and similar). Sapphire hardcodes `wss://dealer.spotify.com/` and sends the web-player `Origin` and `User-Agent`. [S] Network:458-464.
- Keepalive: send `{"type":"ping"}` every 30 s. go-librespot drops the socket if no `pong` arrives within ping interval + 10 s. [GL] dealer.go (`pingInterval = 30 * time.Second`, `timeout = 10 * time.Second`). Sapphire also pings every 30 s. [S] Network:612-631.
- Requests from Spotify that need an answer get `{"type":"reply","key":<key>,"payload":{"success":true}}`. [GL] dealer.go `sendReply`.

### 1.3 Connection id
- The first message is a dealer `message` with uri `hm://pusher/v1/connections/<id>`. Its `headers["Spotify-Connection-Id"]` is the connection id. [LR] https://github.com/librespot-org/librespot/blob/dev/connect/src/spirc.rs (`listen_for("hm://pusher/v1/connections/", extract_connection_id)`); [GL] https://github.com/devgianlu/go-librespot/blob/master/daemon/player.go (`p.spotConnId = msg.Headers["Spotify-Connection-Id"]`); [S] Network:530-540.
- On every reconnect a new id arrives, and you must register the device again with it. [S] Network:680; [LR] spirc.rs `handle_connection_id_update`.

### 1.4 Device registration (what the web player does)
1. *(web-player only, optional for a controller)* `POST https://<spclient>/track-playback/v1/devices` with `{device:{device_id, device_type:"computer", model:"web_player", name, brand:"spotify", capabilities:{...}, platform_identifier, is_group:false}, connection_id, client_version, volume:65535}`. [S] PrivateAPI:1745-1784.
2. `PUT https://<spclient>/connect-state/v1/devices/hobs_<deviceId>`
   with headers `Authorization: Bearer <token>`, `client-token: <ct>`, `X-Spotify-Connection-Id: <connId>`, `Content-Type: application/json`
   and body:
   ```json
   {"member_type":"CONNECT_STATE",
    "device":{"device_info":{"capabilities":{
      "can_be_player":false,"hidden":true,"needs_full_player_state":true,
      "volume_steps":64,"gaia_eq_connect_id":true,"supports_logout":true,
      "is_observable":true,"command_acks":true,"supports_rename":false,
      "supports_playlist_v2":true,"is_controllable":true,
      "supports_command_request":true,"supports_external_episodes":true,
      "supports_set_options_command":true,"supported_types":[]}}}}
   ```
   [S] PrivateAPI:1786-1835. `can_be_player:false` + `hidden:true` makes us an invisible remote that never shows in the device picker. go-librespot, which *is* a player, sends `CanBePlayer:true, Hidden:false, SupportsTransferCommand:true...`: [GL] https://github.com/devgianlu/go-librespot/blob/master/daemon/player_state.go `initState`.
3. The PUT response body is the **cluster** (`active_device_id`, `player_state`, `devices{}`). It is your initial state. [S] PrivateAPI:1797-1813; [LR] spirc.rs parses it as `Cluster`.
- After that, cluster updates are pushed on `hm://connect-state/v1/cluster` [LR] spirc.rs, and you can re-pull them any time with `GET /connect-state/v1/cluster`. [S] PrivateAPI:2329.
- spclient host: from apresolve, fallback `gue1-spclient.spotify.com`. [S] PrivateAPI:329-360.

## 2. Commands

### 2.1 Path and envelope
`POST https://<spclient>/connect-state/v1/player/command/from/<ourDeviceId>/to/<activeDeviceId>`
headers: bearer, client-token, `x-spotify-connection-id`
```json
{"command":{"endpoint":"<name>","logging_params":{"command_id":"<32 hex>"}, ...fields}}
```
[S] PrivateAPI:3216-3235. The receiver sees this on dealer topic `hm://connect-state/v1/player/command`, and the `endpoint` field is the serde tag. [LR] https://github.com/librespot-org/librespot/blob/dev/core/src/dealer/protocol/request.rs (`#[serde(tag = "endpoint", rename_all = "snake_case")]`); [GL] daemon/player.go `handleDealerRequest`.

### 2.2 Bodies (`command` object)
| Action | Body | Source |
|---|---|---|
| **set_queue** (reorder, remove) | `{"endpoint":"set_queue","next_tracks":[ProvidedTrack...],"prev_tracks":[ProvidedTrack...],"queue_revision":"<from cluster>","logging_params":{...}}` | [LR] request.rs `SetQueueCommand{next_tracks, prev_tracks, queue_revision, logging_params}`; [S] PrivateAPI:3140-3165, 3251-3262 |
| **add_to_queue** | `{"endpoint":"add_to_queue","track":{"uri":"spotify:track:..","uid":"<random>","metadata":{"title":..},"provider":"queue"},"queue_revision":"<from cluster>"}`. The player overwrites the uid with `q<N>`. | [LR] `AddToQueueCommand{track, logging_params}`; [S] PrivateAPI:3105-3120 |
| **skip_next** | `{"endpoint":"skip_next"}`, with optional `"track":{uri,uid}` to jump to a specific upcoming track | [LR] `SkipNextCommand{track: Option<ProvidedTrack>}`; [GL] `p.skipNext(req.Command.Track)` |
| **skip_prev** | `{"endpoint":"skip_prev"}` (`options.allow_seeking` is honoured by GL). The web player sends `seek_to` with `value:0` when more than 3 s in. | [LR] `GenericCommand`; [S] PrivateAPI:2955-2965 |
| **play at index** | `{"endpoint":"play","context":{"uri":"spotify:playlist:..","url":"context://spotify:playlist:.."},"play_origin":{"feature_identifier":"..."},"options":{"skip_to":{"track_index":N}}}` (or `track_uid` / `track_uri`) | [LR] `PlayCommand{context, play_origin, options}`, `SkipTo{track_uid, track_uri, track_index}`; [GL] skip-to matches index, then uid, then uri |
| **set_options** | `{"endpoint":"set_options","shuffling_context":bool,"repeating_context":bool,"repeating_track":bool}` | [LR] `SetOptionsCommand`; [GL] `setOptions` |
| **remove from queue** | No endpoint exists. Send `set_queue` without the track. | [LR] no remove variant in `Command`; [S] PrivateAPI:3140 `removeFromQueue` |

`ProvidedTrack` = `{uri, uid, provider, metadata{...}}`. [S] PrivateAPI:3170-3188.

### 2.3 queue_revision
- It is a string in `player_state.queue_revision` of the cluster. [S] Models:352-405. Spicetify exposes it read-only as `Spicetify.Queue.queueRevision`: https://spicetify.app/docs/development/api-wrapper/properties/queue.
- The **player** computes it: librespot hashes the `uri` of each `next_tracks` entry (`DefaultHasher`) and stores the result as a string. [LR] https://github.com/librespot-org/librespot/blob/dev/connect/src/state.rs `update_queue_revision`. librespot also notes: "the web-player needs a revision update, otherwise the queue isn't updated in the ui" ([LR] state/tracks.rs `fill_up_next_tracks`).
- A controller echoes the latest revision it has seen. Neither librespot (`handle_set_queue`) nor go-librespot (`setQueue(prev,next)`) checks it, so on those players a stale revision is harmless. Whether the official desktop or mobile apps reject a stale revision is *unverified*. Treat it as optimistic concurrency: always send the revision from the newest cluster push.

### 2.4 Which device must be registered
- `from/<id>` must be a device that exists in the cluster for this connection. That means the PUT in 1.4 must happen first, and again after every reconnect. [S] registers before any command (PrivateAPI:1786). [LR] and [GL] only ever *receive* commands, so they do not confirm this.
- `to/<id>` is the **active** device (`active_device_id` from the cluster). Sapphire refuses to send when `to == from` and falls back to another external device or the local desktop app. [S] PrivateAPI:3087-3103.
- Volume and transfer use sibling paths: `PUT /connect-state/v1/connect/volume/from/<a>/to/<b>` with `{"volume":0..65535}`, and `POST /connect-state/v1/connect/transfer/from/<a>/to/<b>`. [S] PrivateAPI:1940, 1955.

## 3. Queue vs context tracks
- Every `next_tracks` entry has a `provider`: `"queue"` for tracks the user queued, `"context"` for the playlist or album, and `"autoplay"` for radio fill. Queued tracks get uid `q<N>`. [LR] https://github.com/librespot-org/librespot/blob/dev/connect/src/state/tracks.rs (`add_to_queue`: `track.uid = format!("q{}", self.queue_count)`, `set_provider(Provider::Queue)`); [GL] `addToQueue` uses `fmt.Sprintf("q%d", p.state.queueID)`.
- The player keeps queued tracks **ahead** of context tracks. `add_to_queue` inserts before the first non-queue track. [LR] tracks.rs (`position(|t| !t.is_queue())`). The cap is 80 next and 10 prev. [LR] state.rs (`SPOTIFY_MAX_NEXT_TRACKS_SIZE = 80`, `SPOTIFY_MAX_PREV_TRACKS_SIZE = 10`).
- **Reorder inside one block:** permute that block, keep every other entry exactly as received (same uid, provider and metadata), and send the full list.
- **Across the boundary:** to promote a context track into the queue, set `provider:"queue"` and `metadata.is_queued:"true"` on it. librespot's `set_next_tracks` re-tags tracks flagged as from-queue with `Provider::Queue` and a fresh `q` uid ("mobile only sends a set_queue command instead of an add_to_queue command"). [LR] tracks.rs. Demoting a queued track back into context is not guaranteed to stick. Spotify regenerates context order from the context itself, so *unverified*.
- **Bug in Sapphire to avoid:** `connectQueueTrackPayloads` stamps `provider:"queue"` on **every** track, context tracks included. [S] PrivateAPI:3170-3188. After one remove, the whole upcoming playlist becomes "queued". Vorssaint should pass each track's original `provider` and `uid` through unchanged. Sapphire's `applyQueueRevision` (PrivateAPI:3251) is defined but never called; it has no move-item UI.

## 4. Pitfalls
- **429s:** the web-player token is rate-limited per session, and api.spotify.com throttles it hard. Sapphire uses a per-host plus global cooldown that honours `Retry-After` [S] Network:23-83. Use connect-state and the cluster push for queue reads, never poll `api.spotify.com/v1/me/player/queue`.
- **Token expiry:** bearer lifetime is about 1 h. Refresh early, retry once on 401/403, and refresh **before** reopening the dealer. [S] PrivateAPI:3236-3243, Network:674.
- **TOTP rotation:** when the secret version changes, `/api/token` fails until you ship the new secret. Fetch secrets remotely or scrape them live. Do not hardcode. https://github.com/librespot-org/librespot/discussions/1562, https://github.com/CycloneAddons/spotify-token-generator.
- **Keepalive:** with no ping for about 40 s the dealer drops you, and the new connection id invalidates your device. Re-PUT on every new id. [GL] dealer.go; [S] Network:680.
- **Active device = the Mac desktop app:** this works because it is a normal Connect device. Sapphire falls back to `localSpotifyDesktopDeviceID()` when no device is active. [S] PrivateAPI:3102. If the desktop app has never been active this session, commands can 404 until you `transfer`. *Partly unverified.*
- **Spicetify is not usable from outside.** `Spicetify.Platform.PlayerAPI.addToQueue / removeFromQueue / reorderQueue` exist only inside a patched desktop client, and their names change between versions. https://spicetify.app/docs/development/api-wrapper/methods/platform.
- **ToS:** this endpoint and token are not allowed under the Spotify Developer Terms. Personal use only.
- *Not checked in this pass:* ncspot, spotify-qt, spotify-player, spotifyd, librespot-java, or a 2026 notch or menu bar app that reorders the queue. The ones built on librespot inherit [LR]'s receiver side and are not controllers.

## 5. Plan for Vorssaint (15 lines)
1. Port Sapphire's `TotpGenerator` + `/api/token` flow (Network:800-950, PrivateAPI:1670-1707), with the secrets list fetched remotely.
2. Resolve dealer and spclient via apresolve, falling back to `gue1-dealer` / `gue1-spclient`.
3. Open the dealer websocket, ping every 30 s, reconnect when no pong arrives within 40 s.
4. Read `Spotify-Connection-Id` from `hm://pusher/v1/connections/`.
5. On every new id, `PUT connect-state/v1/devices/hobs_<id>` with the hidden-controller capabilities (§1.4).
6. Store the returned cluster as the state, and apply each `hm://connect-state/v1/cluster` push on top of it.
7. Model each queue row as `{uri, uid, provider, metadata}` with nothing dropped.
8. Show `next_tracks` split into "Queued" (`provider=="queue"`) and "Up next" (context).
9. Drag to reorder means a local permute, then `set_queue` with the full `next_tracks` + `prev_tracks` + latest `queue_revision`.
10. Remove means `set_queue` without the row. Add means `add_to_queue`.
11. Dragging a context track into Queued sets `provider:"queue"` + `is_queued:"true"`. Block drags the other way.
12. Tap a row means `skip_next` with `track:{uri,uid}`. Fall back to `play` with `skip_to.track_uid`.
13. Apply changes optimistically, then reconcile on the next cluster push and roll back on non-2xx.
14. Share one 429 backoff across hosts, refresh the token at 50 min, and retry once on 401/403.
15. Test against the Mac desktop app, a phone and go-librespot (whose debug log prints `set_queue` payloads).

Best repo to copy from: **Sapphire** (our own Swift code, already working) for the controller side, checked against **librespot** `core/src/dealer/protocol/request.rs` + `connect/src/state/tracks.rs` for the exact schema and provider rules.
