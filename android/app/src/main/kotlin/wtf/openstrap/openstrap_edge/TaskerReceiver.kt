package wtf.openstrap.openstrap_edge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class TaskerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "onReceive: action=$action")
        val pkg = context.packageName
        val isStopAction = action == ACTION_BUZZ_STOP ||
                action == "$pkg.BUZZ_STOP" ||
                action == "$pkg.STOP_BUZZ"
        val isStartLoopAction = action == ACTION_BUZZ_START_LOOP ||
                action == "$pkg.BUZZ_START_LOOP" ||
                action == "$pkg.BUZZ_LOOP"
        val isBuzzAction = isStopAction ||
                isStartLoopAction ||
                action == ACTION_BUZZ_STRAP ||
                action == "$pkg.BUZZ_STRAP" ||
                action == "$pkg.BUZZ_CUSTOM" ||
                action == "$pkg.BUZZ_SINGLE" ||
                action == "$pkg.BUZZ_DOUBLE" ||
                action == "$pkg.BUZZ_TRIPLE" ||
                action == "$pkg.BUZZ_ALARM" ||
                action == "$pkg.BUZZ_SOS"
        if (!isBuzzAction) return

        // The token rides as a plain intent extra. If Tasker (or anything
        // else) sends this as an IMPLICIT broadcast (no setPackage/
        // setComponent), Android delivers it to every app on the device with
        // a matching action intent-filter — including a hostile one that
        // declares the same action just to eavesdrop on the extras. That app
        // could then replay the captured token straight at us later. Require
        // the delivered intent to have been explicitly targeted at this app
        // (our Settings → Automation copy already instructs "set Package to
        // wtf.openstrap.openstrap_edge") BEFORE even looking at the token.
        if (intent.`package` != context.packageName &&
            intent.component?.packageName != context.packageName
        ) {
            Log.w(TAG, "rejected: not explicitly targeted at this app")
            return
        }

        // This receiver is exported with no manifest permission (a signature
        // permission would block Tasker itself, since it isn't signed by us) —
        // so anyone who can send an explicitly-targeted broadcast can still
        // reach it. Require a per-install shared secret the user copies from
        // Settings → Automation into their Tasker action, plus a short rate
        // limit as defense in depth. See NativeChannels.getOrCreateTaskerToken.
        val expected = NativeChannels.getOrCreateTaskerToken(context)
        val provided = intent.getStringExtra(EXTRA_TOKEN)
        if (provided == null || provided != expected) {
            Log.w(TAG, "rejected: missing/incorrect token")
            return
        }

        // STOP action: immediate cancellation with NO rate limit
        if (isStopAction) {
            Log.i(TAG, "handling BUZZ_STOP: cancelling active vibration loop")
            val prefs = context.getSharedPreferences("openstrap_runtime", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(PENDING_LOOP_KEY, false)
                .remove(PENDING_LOOP_KEY)
                .remove(PENDING_LOOP_INTERVAL_KEY)
                .remove(PENDING_TIMEOUT_KEY)
                .commit()

            val engine = FlutterEngineCache.getInstance().get(EdgeApplication.ENGINE_ID)
            if (engine != null) {
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    NativeChannels.TASKER_CHANNEL
                ).invokeMethod("stop_buzz_loop", null)
            }
            return
        }

        val nowElapsed = SystemClock.elapsedRealtime()
        if (nowElapsed - lastAcceptedElapsedMs < MIN_INTERVAL_MS) {
            Log.w(TAG, "rejected: rate-limited (< ${MIN_INTERVAL_MS}ms since last accepted broadcast)")
            return
        }
        lastAcceptedElapsedMs = nowElapsed

        val isLoop = isStartLoopAction || intent.getBooleanExtra(EXTRA_LOOP, false)
        val loopIntervalMs = intent.getIntExtra(EXTRA_LOOP_INTERVAL_MS, 1500).coerceIn(500, 30000)
        val timeoutSec = intent.getIntExtra(EXTRA_TIMEOUT_SEC, 90).coerceIn(5, 600)

        var patternName: String? = intent.getStringExtra(EXTRA_NAME)
        if (patternName == null) {
            patternName = when (action) {
                "$pkg.BUZZ_SINGLE" -> "single"
                "$pkg.BUZZ_DOUBLE" -> "double"
                "$pkg.BUZZ_TRIPLE" -> "triple"
                "$pkg.BUZZ_ALARM" -> "alarm"
                "$pkg.BUZZ_SOS" -> "sos"
                else -> intent.getStringExtra(EXTRA_PATTERN)
            }
        }

        var pattern = intent.getIntExtra(EXTRA_PATTERN, -1)
        if (pattern == -1) {
            pattern = when (patternName?.lowercase()) {
                "single" -> 0
                "alarm" -> 1
                "double" -> 2
                else -> DEFAULT_PATTERN
            }
        }

        val sequence = intent.getStringExtra(EXTRA_SEQUENCE)
        val count = intent.getIntExtra(EXTRA_COUNT, 1).coerceIn(1, 10)
        val delayMs = intent.getIntExtra(EXTRA_DELAY_MS, 350).coerceIn(50, 3000)
        Log.i(TAG, "pattern=$pattern, name=$patternName, seq=$sequence, count=$count, delayMs=$delayMs, loop=$isLoop, interval=$loopIntervalMs, timeout=$timeoutSec")

        // Persist first, on both paths. A cached engine is no promise of
        // delivery: a just-created engine may not have registered the Dart
        // handler yet (invokeMethod is then dropped), and a long-lived one may
        // have no band link (the write fails without throwing). Dart clears
        // the flag only once the buzz actually reached the strap, and retries
        // it on reconnect until then.
        val prefs = context.getSharedPreferences(
            "openstrap_runtime",
            Context.MODE_PRIVATE
        )
        val editor = prefs.edit()
            .putBoolean(PENDING_BUZZ_KEY, true)
            .putInt(PENDING_PATTERN_KEY, pattern)
            .putInt(PENDING_COUNT_KEY, count)
            .putInt(PENDING_DELAY_KEY, delayMs)
            .putBoolean(PENDING_LOOP_KEY, isLoop)
            .putInt(PENDING_LOOP_INTERVAL_KEY, loopIntervalMs)
            .putInt(PENDING_TIMEOUT_KEY, timeoutSec)
            .putLong(PENDING_AT_KEY, System.currentTimeMillis())

        if (patternName != null) {
            editor.putString(PENDING_PATTERN_NAME_KEY, patternName)
        } else {
            editor.remove(PENDING_PATTERN_NAME_KEY)
        }

        if (sequence != null) {
            editor.putString(PENDING_SEQUENCE_KEY, sequence)
        } else {
            editor.remove(PENDING_SEQUENCE_KEY)
        }

        editor.commit()

        val engine = FlutterEngineCache.getInstance()
            .get(EdgeApplication.ENGINE_ID)

        if (engine != null) {
            Log.i(TAG, "engine alive, nudging Dart to deliver the pending buzz")
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                NativeChannels.TASKER_CHANNEL
            ).invokeMethod("buzz_strap", null)
            return
        }

        Log.i(TAG, "engine dead, starting service to deliver the pending buzz")
        EdgeTrackingService.startFromBackground(context, TAG)
    }

    companion object {
        const val TAG = "TaskerReceiver"
        const val ACTION_BUZZ_STRAP =
            "wtf.openstrap.openstrap_edge.BUZZ_STRAP"
        const val ACTION_BUZZ_START_LOOP =
            "wtf.openstrap.openstrap_edge.BUZZ_START_LOOP"
        const val ACTION_BUZZ_STOP =
            "wtf.openstrap.openstrap_edge.BUZZ_STOP"
        const val EXTRA_PATTERN = "pattern"
        const val EXTRA_NAME = "name"
        const val EXTRA_SEQUENCE = "sequence"
        const val EXTRA_COUNT = "count"
        const val EXTRA_DELAY_MS = "delay_ms"
        const val EXTRA_TOKEN = "token"
        const val EXTRA_LOOP = "loop"
        const val EXTRA_LOOP_INTERVAL_MS = "interval_ms"
        const val EXTRA_TIMEOUT_SEC = "timeout_sec"

        const val PENDING_BUZZ_KEY = "pending_tasker_buzz"
        const val PENDING_PATTERN_KEY = "pending_tasker_buzz_pattern"
        const val PENDING_PATTERN_NAME_KEY = "pending_tasker_buzz_pattern_name"
        const val PENDING_SEQUENCE_KEY = "pending_tasker_buzz_sequence"
        const val PENDING_COUNT_KEY = "pending_tasker_buzz_count"
        const val PENDING_DELAY_KEY = "pending_tasker_buzz_delay_ms"
        const val PENDING_LOOP_KEY = "pending_tasker_buzz_loop"
        const val PENDING_LOOP_INTERVAL_KEY = "pending_tasker_buzz_loop_interval_ms"
        const val PENDING_TIMEOUT_KEY = "pending_tasker_buzz_timeout_sec"
        const val PENDING_AT_KEY = "pending_tasker_buzz_at_ms"
        const val DEFAULT_PATTERN = 2
        private const val MIN_INTERVAL_MS = 1500L

        // Process-lifetime, not persisted — a fresh process restarting the
        // rate-limit window on cold start is fine; the goal is only to blunt a
        // tight resend loop within one running process.
        @Volatile
        private var lastAcceptedElapsedMs = 0L
    }
}
