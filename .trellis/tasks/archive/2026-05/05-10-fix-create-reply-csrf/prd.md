# Fix csrf check error in createReply

## Problem
`createReply` throws "Exception: csrf check error" when posting to `/posts.json` (non-NodeSeek Discourse API path). The error occurs because the method lacks `try/catch` with `_throwApiError` — every other POST mutation in `_posts.dart` has this wrapper.

## Root Cause
In `_posts.dart:52`, `_dio.post('/posts.json')` is called without `try { } on DioException catch (e) { _throwApiError(e); }`. When the CSRF retry interceptor (in `_auth.dart`) fails to recover from a 403, the raw `DioException` propagates to the caller uncaught.

The auth interceptor already handles one CSRF retry — clears stale token, refreshes, re-sends. But if *both* attempts fail, there's no error extraction layer.

## Fix
Wrap the `_dio.post('/posts.json')` call in `_posts.dart` (the non-NodeSeek branch, lines 46-56) with:

```dart
try {
  final response = await _dio.post(...);
  // ... existing respData processing ...
} on DioException catch (e) {
  _throwApiError(e);
}
```

This matches the existing pattern used by `likePost`, `updatePost`, `bookmarkTopic`, `flagPost`, `acceptAnswer`, `deletePost`, `recoverPost`, and `saveDraft`.
