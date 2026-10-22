# GroMore public bridge APIs are also reached by dynamically loaded SDK code.
# The SDK AAR supplies additional consumer rules for its native/plugin internals.
-keep class com.bytedance.sdk.openadsdk.** { *; }
-keep class bykvm*.** { *; }
-keep class com.bytedance.msdk.adapter.** { public *; }
-keep class com.bytedance.msdk.api.** { public *; }
