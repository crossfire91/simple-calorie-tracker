package com.example.simple_calorie_tracker

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersion" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        info.longVersionCode.toInt()
                    } else {
                        @Suppress("DEPRECATION")
                        info.versionCode
                    }
                    result.success(
                        mapOf(
                            "versionName" to (info.versionName ?: ""),
                            "versionCode" to code,
                        ),
                    )
                }
                "canInstallPackages" -> {
                    result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        },
                    )
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            },
                        )
                    }
                    result.success(true)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "path missing", null)
                    } else {
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("install_failed", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        CalorieWidgetStore.save(
                            this@MainActivity,
                            asInt(args["consumedKcal"], 0),
                            asInt(args["budgetKcal"], 2500),
                            args["dateKey"] as? String ?: "",
                            args["lang"] as? String ?: "de",
                            asInt(args["mealCount"], 0),
                            parseFavorites(args["favorites"]),
                            args["coachLineDe"] as? String ?: "",
                            args["coachLineEn"] as? String ?: "",
                            args["coachMood"] as? String ?: "nextPlate",
                            asInt(args["proteinGrams"], 0),
                            asInt(args["proteinTarget"], 90),
                            args["proteinName"] as? String ?: "",
                            args["proteinFavoriteId"] as? String ?: "",
                            asInt(args["streak"], 0),
                        )
                        WidgetHub.refreshAll(this@MainActivity)
                        result.success(true)
                    }
                    "updateLang" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        CalorieWidgetStore.saveLang(this@MainActivity, args["lang"] as? String ?: "de")
                        WidgetHub.refreshAll(this@MainActivity)
                        result.success(true)
                    }
                    "takeLaunchAction" -> result.success(consumeLaunchAction(intent))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = consumeLaunchAction(intent)
        if (payload != null) {
            channel?.invokeMethod("onWidgetAction", payload)
        }
    }

    private fun consumeLaunchAction(source: Intent?): Map<String, String>? {
        if (source == null) return null
        val action = source.getStringExtra(WidgetHub.EXTRA_ACTION) ?: return null
        val favoriteId = source.getStringExtra(WidgetHub.EXTRA_FAVORITE_ID) ?: ""
        source.removeExtra(WidgetHub.EXTRA_ACTION)
        source.removeExtra(WidgetHub.EXTRA_FAVORITE_ID)
        return mapOf(
            "action" to action,
            "favoriteId" to favoriteId,
        )
    }

    private fun parseFavorites(raw: Any?): List<CalorieWidgetStore.FavoriteChip> {
        val list = raw as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val id = map["id"] as? String ?: return@mapNotNull null
            val name = map["name"] as? String ?: return@mapNotNull null
            if (id.isEmpty() || name.isEmpty()) return@mapNotNull null
            CalorieWidgetStore.FavoriteChip(
                id = id,
                name = name,
                kcal = asInt(map["kcal"], 0),
            )
        }.take(2)
    }

    private fun asInt(value: Any?, fallback: Int): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            is Float -> value.toInt()
            else -> fallback
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("apk missing")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    companion object {
        private const val CHANNEL = "simple_calorie_tracker/home_widget"
        private const val UPDATE_CHANNEL = "simple_calorie_tracker/app_update"
    }
}
