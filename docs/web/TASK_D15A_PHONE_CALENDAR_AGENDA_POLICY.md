# TASK D15A - Phone Calendar Agenda Input Policy

## Status

`DESIGN COMPLETE - ANDROID OWNER FLOW SUPERSEDED BY D15B`

D15A defines a safe source for the two existing agenda rows in Product Mode.
It changes no firmware, web runtime, BLE protocol, panel renderer, or persisted
device data.

Owner follow-up on Android found that exporting `.ics` from the phone is too
awkward for the normal workflow. D15B therefore promotes explicit read-only
Google Calendar OAuth to the primary source and keeps local `.ics` as a
fallback policy. See `TASK_D15B_GOOGLE_CALENDAR_AGENDA.md`.

Canonical URL:

`https://onlysky17.github.io/Clock/test.html`

## Platform Finding

A normal browser page cannot directly read every calendar stored by Android or
iOS through one portable Web API.

- Apple calendar access is provided through native EventKit and requires native
  application permission.
- Google Calendar access requires Google OAuth, an account-specific API, scopes,
  consent configuration, and possibly application verification.
- A browser can read a local file only after the owner explicitly selects it.

Therefore D15 must not claim automatic native-calendar access from the current
GitHub Pages application.

## Approved MVP

Choose **local iCalendar file import** for D15B.

Owner flow:

1. Export or share a calendar as an `.ics` file on the phone.
2. Press `Chọn lịch .ics` in Product Mode.
3. Select the file through the browser file picker.
4. Review the two proposed agenda rows.
5. Press the existing `Áp dụng lên màn` action.

The browser reads the selected file locally with `<input type="file">` and the
File API. Calendar content is not uploaded to the Clock repository, GitHub,
Open-Meteo, or another service.

## Input Boundary

- Accept `.ics` / `text/calendar` only.
- Maximum selected file size: `1 MiB`.
- Require `VCALENDAR` and bounded `VEVENT` records.
- Read only fields required for the panel:
  - `DTSTART`;
  - `DTEND` when present;
  - `SUMMARY`;
  - `STATUS`;
  - `RECURRENCE-ID` when present.
- Ignore descriptions, attendees, organizer, location, attachments, alarms,
  URLs, and conferencing data.
- Reject malformed date/time values instead of guessing.
- Never execute HTML, URLs, scripts, or attachment content from the calendar.

The iCalendar date boundary follows RFC 5545: `DTSTART` is inclusive and
`DTEND` is non-inclusive.

## Event Selection

Use the same local date and timezone offset already sent by D2 SET_TIME.

- Include timed events whose local start date is today.
- Exclude `STATUS:CANCELLED`.
- Exclude all-day entries in the MVP because the current D2 agenda rows require
  a minute value.
- Sort by local start minute, then source order.
- Prefer current or upcoming events.
- If fewer than two current/upcoming events exist, fill remaining rows with the
  latest earlier events from the same day.
- Send at most two rows.
- Empty results preserve empty agenda rows and show a clear Vietnamese status.

## Label Mapping

The existing firmware contract allows a three-character `A-Z` / `0-9` label.

- Normalize `SUMMARY` to uppercase ASCII.
- Remove Vietnamese diacritics and punctuation.
- Suggest the first three alphanumeric characters.
- Show the suggested code in the existing editable agenda fields.
- Never send a generated label until the owner reviews and applies it.
- An empty or unusable summary leaves the row empty.

This keeps the bounded D2 payload unchanged while avoiding unexplained labels.

## Recurrence And Timezone Safety

D15B must not implement a pretend full calendar engine.

- Direct `VEVENT` instances and explicit `RECURRENCE-ID` instances are eligible.
- A recurring master that needs `RRULE` expansion is not expanded in the MVP.
- Unsupported recurrence or timezone definitions produce a visible warning;
  they do not silently create the wrong time.
- UTC timestamps are converted to the browser/D2 local timezone.
- Local timestamps without a supported timezone are treated as floating local
  time only when RFC syntax is valid.

A later task may add a proven RFC 5545 recurrence parser after browser size and
offline behavior are audited.

## Privacy And Lifetime

- Import is always an explicit owner action.
- No automatic file picker prompt.
- No upload and no background calendar request.
- No `localStorage`, IndexedDB, cookie, SPI, or NVDS persistence.
- Raw calendar text and parsed events remain page-session RAM only.
- Reloading or closing the page clears imported calendar data.
- BLE disconnect does not expose or transmit calendar content.
- Only the two reviewed bounded rows are sent through the existing D2 payload.

## Rejected MVP Alternatives

### Direct native phone calendar

Rejected for the current web application. Native iOS EventKit is not available
to a normal GitHub Pages browser page, and there is no cross-platform equivalent
that reads every Android/iOS calendar.

### Google Calendar OAuth

Deferred. It supports read-only event scopes, but adds account login, OAuth
configuration, consent, token handling, provider lock-in, and possible app
verification. It is not required for the first safe MVP.

### Calendar URL subscription

Deferred. Private subscription URLs act like secrets, require network fetching
and CORS support, and must not be stored casually in browser state.

## Preserved Contracts

- Existing D2 daily SET/GET/status packet lengths and command IDs remain exact.
- Existing two agenda rows remain optional and editable.
- Weather, profiles, automatic weather, scheduler, EPD flow, and persistence
  remain unchanged.
- No firmware build, pack, flash, or physical panel test is required for D15A.

## D15B Exact Scope

`TASK D15B - IMPLEMENT LOCAL ICS AGENDA IMPORT`

Maximum expected tracked files:

1. `web/clock-app/hl24a-canvas-e5.html`
2. `scripts/task-d15b-local-ics-agenda-import-smoke.mjs`
3. this policy document or a narrow D15B implementation document

D15B must add owner-selected local import, bounded parsing, editable preview,
Vietnamese status text, desktop/mobile browser tests, and no protocol changes.

## Primary References

- MDN file input:
  <https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file>
- MDN File API:
  <https://developer.mozilla.org/en-US/docs/Web/API/File_API>
- RFC 5545 iCalendar:
  <https://datatracker.ietf.org/doc/html/rfc5545>
- Apple EventKit permission model:
  <https://developer.apple.com/documentation/eventkit/accessing-the-event-store>
- Google Calendar OAuth scopes:
  <https://developers.google.com/workspace/calendar/api/auth>
