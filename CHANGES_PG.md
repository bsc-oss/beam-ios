## Changes in 1.0.4

✨ Features
- feat flag change

## Changes in 1.0.3

Upstream merge ✨:
- base update to v26.05.3 (https://github.com/element-hq/element-x-ios/tree/release/26.05.3)
- reverts the upstream "Remove this device" rename back to "Sign out" (copy and sign-out icon)
- puts back the room directory search behind a feature flag (while upstream removed it)
- disables invite via DM for now, to re-asseess later
- interverts the order of the "manage my app" and "manage account" sections in Settings screen (same behaviour as previous upstream version)

🐛 Bugfixes
- hides call button when user is alone in room in room details screen
- hide the "New members don't see history" badge for DMs (new members don't apply to a DM)


## Changes in 1.0.2

✨ Features
- Adds remote service-message (notice) banner shown above the room list and on the first-account login screen. Configurable per environment via `PG_NOTICE_URL`. Server-controlled severity (informative/critical), dismissibility, localisation and instant hide via `isActive`.


## Changes in 1.0.1

Upstream merge ✨:
- Base update to v26.03.3 (https://github.com/element-hq/element-x-ios/tree/release/26.03.3)

🐛 Bugfixes
- add cancel/close button to qr login modal
- Fix home screen profile icon showing MXID initial instead of profile picture or display name initial on app startup
- Fixes user ID being displayed instead of email in reactions summary view

🧱 Build

✨ Features
- Adds hidden users UX improvements
- Makes user ID copyable in user edit, user profile & room member details screens

🙌 Improvements
- Remove high contrast colors as they are not used.
- Use of Beam theming

🚧 In development 🚧

🗣 Translations

Others


## Changes in 1.0.0

🗣 Translations
- translations fixes

## Changes in 0.0.1

Upstream merge ✨:
  - Base update to v26.01.0 (https://github.com/element-hq/element-x-ios/tree/release/26.01.0)

🐛 Bugfixes

🧱 Build
- adapts the build sdk scripts to use local pg-rust-sdk instead of matrix-rust-components-swift (until we have a custom version of components-swift in our nexus)
- allows build variant per environment

✨ Features
- adds email input screen with a11y ids and new translations
- adapts routing so login button navigates to new email input screen
- gets homeserver url based on email entered by user thanks to the email validation service
- disables account creation
- sets pg service url
- adapts oidcRedirectUrl to be.bsc.devserver.local.debug
- adapts push gateway base url to dev synal server url
- removes posthog Element configuration
- replaces app icon
- adopts pg specific styling
- adds support for search by full email
- adds email field to room heroes
- displays email instead of mxid app wise
- fetch upstream changes from 25.10.0 (until 6e36817)
- fixes display name and avatar url (read and edit)
- add custom profile fields
- Reciprocate QR login
- removes element io web urls references
- sets earpiece as default sound output and puts earpiece as first in the sound output list in call settings
- upgrades pg-call to latest (includes speaker button change, fix for waiting overlay & waiting tone, earpiece first in audio settings list)
- fixes background color for primary action button
- fixes crash when pressing quickly multiple times on the email input screen continue button (#34)
- In the onboarding, the create profile screen doesn't force you to change fields (before setting a function was required). Only requirement now is to have a non empty display name (#35).
- clear the flag regarding the onboarding profile creation during logout. This way, on next user login, the profile creation will appear.
- adapts the organization name from Element to BSC
- renames the app name from ElementX to Beam
- adapts onboarding translation from Pro grade to Beam
- adapts app icons and app logo
- show email instead of mxid on the invite screen
- fixes translations
- displays email in room header view subtitle of RoomScreen and ThreadTimelineScreen
- displays email for DM rooms in message forwarding, global search and share destination list
- adds email in invite notification
- Force app lock when user has no OS-level app lock set.
- disables tablet app distribution
- Add new MAS scope "urn:pg:mas-logout" to revoke sessions on log-out.
- Option to update Phonebook consent via profile settings
- Change minimum search length from 3 to 2
- Show warning dialog when clicking any hyperlink in messages (waterfall: suspicious links show specific warning, all other links show general warning).
- Show warning dialog when sharing/saving a file.
- puts translate TimelineItemMenuAction behind a feature flag (disabled by default)
- removes dev settings toggle, restricts "copy link to msg" and "view source" actions as toggles to dev builds only
- Block potential dangerous files (see PgFileTypeBlocklist.swift) from uploading, downloading or sharing.
- Disable room, profile & invite friends sharing feature (via shareProfileEnabled, inviteFriendsEnabled & shareRoomEnabled featureflags)
- Adds `publicRoomCreationEnabled` feature flag (disabled by default) to hide the public room/space access type from both creation and security & privacy editing screens
- Adds `joinRoomByAddressEnabled` feature flag (disabled by default) to hide the "Join group by address" option from the start chat screen
- Replaces video call icon by voice call icon in the home screen room cells, in the room screen and in the call notification timeline view.
- Hides call button when user is alone in room
- Restricts "report content" timeline item menu action to dev builds only (disabled by default)
- Disables spaces feature (via `spacesEnabled` feature flag, disabled by default)
- Disable threads & don't allow users to enable it via Labs.

🙌 Improvements
-   Remove legacy warning from caption in Filepreview
-   Change matrix-to endpoint. 

🚧 In development 🚧

🗣 Translations

Others
