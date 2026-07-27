# TASK D15B - Google Calendar Agenda

## Status

`IMPLEMENTED - READY FOR WEB REVIEW`

Canonical URL:

`https://onlysky17.github.io/Clock/test.html`

D15B replaces the Android-unfriendly `.ics` primary flow from D15A with an
owner-triggered Google Calendar connection. Local `.ics` remains the fallback
policy when Google Calendar is unavailable; it is not required for this
implementation.

## Owner Flow

1. Open `Tóm tắt trong ngày`.
2. Press `Kết nối Google Calendar`.
3. Approve read-only calendar access.
4. Press `Lấy lịch hôm nay`.
5. Review the two proposed times and three-character codes.
6. Press the existing `Áp dụng lên màn`.

Reading Google Calendar does not require BLE. Applying the reviewed rows still
uses the existing connected-device D2 flow.

## Google Cloud Configuration

The static GitHub Pages app uses a dedicated EINK Clock Google Cloud project:

- Project ID: `eink-clock-onlysky17`.
- Google Calendar API: enabled.
- OAuth client type: Web application.
- Authorized JavaScript origin: `https://onlysky17.github.io`.
- Public Client ID:
  `64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6.apps.googleusercontent.com`.
- The Client ID is stored in the `google-calendar-client-id` meta element.

Do not use an unrelated PlantApp project. A browser OAuth Client ID is public
configuration; no client secret belongs in the repository.

## Read Boundary

- Scope: `https://www.googleapis.com/auth/calendar.readonly`.
- Source: the signed-in account's `primary` calendar.
- Query only the current local day with `timeMin` and `timeMax`.
- Use `singleEvents=true` and `orderBy=startTime`.
- Ignore cancelled and all-day events.
- Prefer current/upcoming timed events, then the latest earlier events.
- De-duplicate identical start minutes.
- Return at most two rows.

## Label And Review

- Normalize event titles to ASCII uppercase.
- Remove Vietnamese diacritics and punctuation.
- Use at most three `A-Z` / `0-9` characters.
- Display the original event title next to the editable time and code.
- Never send calendar data until the owner presses the existing apply action.

The D2 daily packet remains unchanged:

- SET `D2 08`, 20 bytes.
- GET `D2 09`, 2 bytes.
- Existing status `D2 88`, 20 bytes.

## Privacy And Lifetime

- OAuth is an explicit owner action.
- The short-lived access token is kept in `sessionStorage`, never
  `localStorage`, so a reload in the same tab can reuse it until Google expiry.
- Closing the tab, `Ngắt quyền lịch`, malformed/expired session data, or an HTTP
  401 response clears the saved token.
- Calendar events and titles remain RAM-only and are fetched again after reload.
- No event data is stored in browser storage, SPI, or NVDS.
- `Ngắt quyền lịch` clears the tab session and revokes the current access token.
- Only two reviewed bounded agenda rows are sent to the device.
- The D15C follow-up restores device rendering for the agenda bytes already
  carried by this unchanged D2 packet.
- No BLE protocol, scheduler, weather source, or browser storage change.
- Không đổi BLE protocol.

## Device rendering

The `DAILY_BRIEFING` face keeps the monthly calendar and renders imported agenda
rows below the left clock pane. With one agenda row, the compact weather row
remains visible. The lunar, weather, and agenda rows are centered with balanced
vertical spacing, and the large clock moves upward to use the left pane evenly.
The common `HOP` code is rendered visually as Vietnamese `HỌP` without changing
the three-byte BLE label. With two agenda rows, both compact lines are used for
events.

## Current-time filtering

- The web keeps only events that are still running or start later today.
- Ended events are never reused to fill an empty agenda row.
- After the owner fetches the calendar and applies the daily briefing once, the
  open page checks the cached event list every 30 seconds.
- When the visible rows change, an eligible connected daily-briefing device
  receives the updated rows and one normal render request.
- The check pauses while disconnected, hidden, busy, incompatible, or on
  another clock face; it never auto-connects.
- Google Calendar is not queried every 30 seconds. The timer filters only the
  page-session data already fetched by the owner.

## Same-tab access recovery

- D15E restores a valid short-lived Google access token after reload in the
  same open tab.
- The expiry supplied by Google is preserved with a one-minute safety margin.
- This reduces repeated sign-in prompts but does not bypass Google's OAuth
  consent, test-user, or application-verification rules.
- D15F automatically fetches today's agenda when that valid token is restored.
- The restored agenda only repopulates the review controls. It never sends BLE
  data or refreshes the panel until the owner presses `Áp dụng lên màn`.
- Event titles remain RAM-only and are fetched again from Google after reload.

## Validation

`node scripts/task-d15b-google-calendar-agenda-smoke.mjs`

The smoke uses a browser-side mock for Google OAuth and Calendar REST. It
checks desktop/mobile layout, two-row selection, Vietnamese normalization,
all-day exclusion, page-session-only state, and unchanged D2 packet IDs and
lengths.

D15E session recovery is validated by:

`node scripts/task-d15e-google-session-access-smoke.mjs`

D15F agenda restoration is validated by:

`node scripts/task-d15f-restore-google-agenda-smoke.mjs`

Official references:

- Google Identity Services token model:
  <https://developers.google.com/identity/oauth2/web/guides/use-token-model>
- Google Calendar `events.list`:
  <https://developers.google.com/calendar/api/v3/reference/events/list>
- Google OAuth client credentials:
  <https://developers.google.com/workspace/guides/create-credentials>
