# Article like notifications — 2026-10-09

The article like endpoint saved likes and emitted reaction updates, but never
created notifications for article authors. Production had two missed likes.

Migration 038 creates notifications transactionally after a new article like,
excluding self-likes, unavailable users or posts, and blocked relationships.
A partial unique index prevents repeated requests and unlike/re-like actions
from sending duplicate notifications. Existing likes are repaired using their
original timestamps. The existing notification trigger emits durable realtime
events without adding another transport.

The client displays “收到新的赞” with the like icon. Opening the notification
fetches the corresponding article before marking the notification read. A failed
article request leaves it unread.

Validation: 15 Flutter notification/message/realtime tests and static analysis
passed. Both ArticleLikeNotificationsIntegration and RealtimeOutboxIntegration
passed against an isolated PostgreSQL container, including migration backfill,
deduplication, rollback and realtime delivery.

Production image: `bojian-api:like-notifications-20261009-r1`.
Readiness and binary checksum passed after deployment. Production contains two
article like notifications, both unread at verification. Release APK installed
successfully on device b738806e. The user was using another app, so the app was
not opened and the real notifications were not marked read during verification.

API SHA256: `63364031606c240c369ed0973bf8d1953d2940c92184b6cd201aa6346df484c1`

APK SHA256: `c6da721e7d46eb8368683ae6b24aeaf1cad005a27672da8d6bb9d842a35a3ba2`

This uses the existing foreground realtime connection; it does not add operating
system background push notifications.
