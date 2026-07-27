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
- Access token and event data stay in page-session RAM.
- No `localStorage`, session storage, IndexedDB, cookie, SPI, or NVDS storage.
- Reloading or closing the tab clears the token and events.
- `Ngắt quyền lịch` revokes the current access token.
- Only two reviewed bounded agenda rows are sent to the device.
- No firmware, BLE protocol, scheduler, weather, or panel renderer change.
- Không đổi BLE protocol hoặc firmware.

## Validation

`node scripts/task-d15b-google-calendar-agenda-smoke.mjs`

The smoke uses a browser-side mock for Google OAuth and Calendar REST. It
checks desktop/mobile layout, two-row selection, Vietnamese normalization,
all-day exclusion, page-session-only state, and unchanged D2 packet IDs and
lengths.

Official references:

- Google Identity Services token model:
  <https://developers.google.com/identity/oauth2/web/guides/use-token-model>
- Google Calendar `events.list`:
  <https://developers.google.com/calendar/api/v3/reference/events/list>
- Google OAuth client credentials:
  <https://developers.google.com/workspace/guides/create-credentials>
