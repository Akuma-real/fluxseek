# Fix Startup Nav And Topic Badges

## Problem

Three visible UI regressions remain after `v0.1.0-beta.7`:

1. Customized bottom navigation flashes the anonymous entry set during startup.
   - Example: the user configures `首页 / 我的 / 书签`, but app launch first renders `首页 / 我的`; after login state resolves, `书签` appears.
   - The startup shell should preserve configured navigation shape while auth state is loading.

2. Bookmark topic rows reserve a left avatar gutter even though bookmark source data often has no author avatar.
   - The empty avatar slot makes bookmark rows look misaligned and unfinished.
   - The bookmark list should use the available horizontal space instead of keeping a fake author/avatar area.

3. Homepage topic category/tag signals are not readable enough, and many categories miss icons.
   - Category and tag badges should be easier to scan in topic cards.
   - NodeSeek static category icon names such as `tea`, `formula`, `receiver`, and `texture` should resolve to sensible Flutter icons instead of falling back to dots whenever they are not FontAwesome names.

## Scope

- Flutter app UI only.
- Do not change NodeSeek network behavior, cookie/auth persistence, or release tooling.
- Prefer extending existing navigation, topic card, badge, and icon helper code over creating parallel components.

## Acceptance Criteria

- Startup bottom navigation keeps user-configured login-gated entries visible while login state is still loading, so configured entries do not visibly appear later as layout changes.
- Login-gated entries still behave safely when the user is confirmed logged out.
- Bookmark topic list rows no longer reserve an empty avatar slot.
- Normal topic lists keep their existing author/avatar presentation.
- Topic cards make category and tag badges clearer without overcrowding compact mobile layouts.
- NodeSeek static category icon names used by the app map to visible icons where practical.
- `just analyze` passes.
- Focused tests are added or updated where the behavior can be covered without brittle visual assertions.
