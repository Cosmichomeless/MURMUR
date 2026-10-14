# App Store Connect hand-off

Who does what to get MURMUR 1.0.0 from this repository to TestFlight and App Review. The
[App Store Connect MCP](https://github.com/SardorbekR/appstore-connect-mcp) (`asc-mcp`) covers part
of it; the rest has to be done by hand in the web or in Xcode. All text to enter is already written in
[APP_REVIEW.md](APP_REVIEW.md) and [app-store-listing.md](app-store-listing.md).

Fixed values:

| Field | Value |
|---|---|
| Name | `MURMUR` (the same in every language) |
| Bundle ID | `com.cosmichomeless.murmur` |
| Version | `1.0.0` (build number: raise it for every upload) |
| Primary language | English (U.S.) |
| Price | Free, no in-app purchases |
| Privacy policy URL | `https://cosmichomeless.github.io/MURMUR/privacy.html` |
| Support URL | `https://cosmichomeless.github.io/MURMUR/support.html` |
| Marketing URL | `https://cosmichomeless.github.io/MURMUR/` |

## 1. By hand (the MCP cannot do these)

1. Set the signing team on the `MURMUR` target (Signing & Capabilities) so `DEVELOPMENT_TEAM` is saved.
2. **App Store Connect → Apps → New App**: platform iOS, name, primary language, bundle ID, SKU.
   Apple's API does not allow creating the app record.
3. Create an API key (Users and Access → Integrations) with the *App Manager* role and put the Key ID,
   Issuer ID and `.p8` path in the MCP configuration on your own machine. Never commit them.
4. Xcode: **Product → Archive → Distribute App → App Store Connect → Upload**. Wait for processing.
5. TestFlight: create an *external* group, enable the public link, fill in the beta description,
   feedback email and what to test, and submit the build for Beta App Review.

## 2. With the MCP, after step 1.2

Order matters: each tool needs the ID returned by the previous one.

1. `create_bundle_id` (skip if Xcode already registered it), then `list_apps` to get the `appId`.
2. `create_app_version` with platform `IOS`, version `1.0.0`.
3. For each locale in the table below: `create_version_localization` (or `update_version_localization`
   if it already exists) with description, keywords, promotional text, `supportUrl` and `marketingUrl`.
4. `list_app_infos` → `list_app_info_localizations` → `update_app_info_localization` for each locale:
   name `MURMUR`, the subtitle and `privacyPolicyUrl`.
5. `set_app_prices` to free.
6. Screenshots: `list_screenshot_sets` for each localization, then `upload_screenshot`. The MCP cannot
   create an empty set; if the 6.9" set does not exist yet, create it by uploading one screenshot in
   the web first.
7. `list_builds` / `get_build` to check the build finished processing.
8. After the beta starts, `add_beta_tester` for each tester email.

| Language | Text in `app-store-listing.md` | Locale code in App Store Connect |
|---|---|---|
| English (U.S.) | `en` | `en-US` |
| Spanish | `es` | `es-ES` |
| French | `fr` | `fr-FR` |
| German | `de` | `de-DE` |
| Italian | `it` | `it` |
| Portuguese (Brazil) | `pt` | `pt-BR` |

The locale codes are the ones Apple documents; check them with `list_version_localizations` on the
first one you create.

## 3. By hand again, before "Submit for Review"

Neither the MCP nor the API covers these:

1. Select the build for the 1.0.0 version.
2. App Privacy → **Data Not Collected** (reasoning in [APP_REVIEW.md](APP_REVIEW.md)).
3. Age rating questionnaire (expected 4+).
4. Category, content rights and export-compliance answers (the app uses no encryption of its own).
5. **EU trader status (DSA)**: your decision as the developer. Without it the app is not distributed in the EU.
6. App Review information: contact details and the review notes from [APP_REVIEW.md](APP_REVIEW.md).
7. Release option (manual or automatic) and **Submit for Review**.

## Screenshots

Required sizes are 6.9" (for example 1320 × 2868) and 6.5" (for example 1284 × 2778). A screenshot taken
on an iPhone with a 6.9" display is already the right size. Take them in each language you list,
and show the features (search, tags, share, transcript), not only empty screens.

## Exit criteria for going public

From issue #42: at least 20 real testers, 7 days without crashes and an average rating of 4/5 or more
before sending to review.
