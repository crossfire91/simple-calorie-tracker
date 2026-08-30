package com.example.simple_calorie_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

object WidgetHub {
    const val EXTRA_ACTION = "widget_action"
    const val EXTRA_FAVORITE_ID = "favorite_id"
    const val ACTION_OPEN = "com.example.simple_calorie_tracker.WIDGET_OPEN"
    const val ACTION_ADD = "com.example.simple_calorie_tracker.WIDGET_ADD"
    const val ACTION_FAVORITE = "com.example.simple_calorie_tracker.WIDGET_FAVORITE"

    fun refreshAll(context: Context) {
        refresh(context, CalorieWidgetProvider::class.java)
        refresh(context, CoachWidgetProvider::class.java)
        refresh(context, ProteinWidgetProvider::class.java)
        refresh(context, PlateWidgetProvider::class.java)
    }

    fun refresh(context: Context, type: Class<out AppWidgetProvider>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, type))
        if (ids.isEmpty()) return
        val snapshot = CalorieWidgetStore.snapshot(context)
        ids.forEach { id ->
            val views = when (type) {
                CoachWidgetProvider::class.java -> bindCoach(context, snapshot)
                ProteinWidgetProvider::class.java -> bindProtein(context, snapshot)
                PlateWidgetProvider::class.java -> bindPlate(context, snapshot, manager.getAppWidgetOptions(id))
                else -> bindCompact(context, snapshot)
            }
            manager.updateAppWidget(id, views)
        }
    }

    fun todayNumbers(snapshot: CalorieWidgetStore.Snapshot): Triple<Int, Int, Int> {
        val isToday = snapshot.dateKey.isEmpty() || snapshot.dateKey == todayDateKey()
        val consumed = if (isToday) snapshot.consumedKcal else 0
        val budget = if (snapshot.budgetKcal > 0) snapshot.budgetKcal else 2500
        val remaining = budget - consumed
        return Triple(consumed, budget, remaining)
    }

    fun bindCompact(context: Context, snapshot: CalorieWidgetStore.Snapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calorie_widget)
        val numbers = todayNumbers(snapshot)
        val remaining = numbers.third
        val over = remaining < 0
        bindHero(context, views, snapshot, remaining, over)
        views.setTextViewText(R.id.widget_used, usedLine(numbers.first, numbers.second, snapshot, german = snapshot.german))
        bindProgress(views, numbers.first, numbers.second, over)
        bindActions(context, views, snapshot, compact = true)
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, ACTION_OPEN, 0))
        return views
    }

    fun bindCoach(context: Context, snapshot: CalorieWidgetStore.Snapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.coach_widget)
        val remaining = todayNumbers(snapshot).third
        val over = remaining < 0
        bindHero(context, views, snapshot, remaining, over)
        val line = snapshot.coachLine
        views.setTextViewText(
            R.id.widget_coach,
            if (line.isNotBlank()) line else fallbackLine(remaining, over, snapshot.german),
        )
        views.setTextColor(R.id.widget_coach, color(context, if (over) R.color.widget_rose else R.color.widget_text))
        bindActions(context, views, snapshot, compact = false)
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, ACTION_OPEN, 20))
        return views
    }

    fun bindProtein(context: Context, snapshot: CalorieWidgetStore.Snapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.protein_widget)
        val target = if (snapshot.proteinTarget > 0) snapshot.proteinTarget else 90
        val grams = if (snapshot.dateKey.isEmpty() || snapshot.dateKey == todayDateKey()) {
            snapshot.proteinGrams
        } else {
            0
        }
        val left = (target - grams).coerceAtLeast(0)
        val progress = ((grams.toLong() * 1000L) / target.toLong()).toInt().coerceIn(0, 1000)
        val german = snapshot.german
        views.setTextViewText(R.id.widget_title, if (german) "Protein" else "Protein")
        views.setTextViewText(R.id.widget_remaining, grams.toString())
        views.setTextViewText(
            R.id.widget_label,
            if (german) "VON $target G" else "OF $target G",
        )
        views.setTextViewText(
            R.id.widget_coach,
            when {
                left <= 0 && german -> "Protein steht. Der Ring kann atmen."
                left <= 0 -> "Protein is in. The ring can breathe."
                german -> "Noch $left g. Ein proteinreiches Essen reicht."
                else -> "$left g still open. One high-protein plate."
            },
        )
        views.setProgressBar(R.id.widget_progress, 1000, progress, false)
        val chip = snapshot.proteinName
        if (chip.isNotBlank() && snapshot.proteinFavoriteId.isNotBlank() && left > 0) {
            views.setViewVisibility(R.id.widget_fav_0, View.VISIBLE)
            views.setTextViewText(R.id.widget_fav_0, chip)
            views.setOnClickPendingIntent(
                R.id.widget_fav_0,
                launch(context, ACTION_FAVORITE, 40, "favorite", snapshot.proteinFavoriteId),
            )
        } else {
            views.setViewVisibility(R.id.widget_fav_0, View.GONE)
        }
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, ACTION_OPEN, 30))
        return views
    }

    fun bindPlate(
        context: Context,
        snapshot: CalorieWidgetStore.Snapshot,
        options: Bundle? = null,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.plate_widget)
        val numbers = todayNumbers(snapshot)
        val consumed = numbers.first
        val remaining = numbers.third
        val over = remaining < 0
        val german = snapshot.german
        val today = snapshot.dateKey.isEmpty() || snapshot.dateKey == todayDateKey()
        val meals = if (today) snapshot.meals else emptyList()
        val mealCount = if (today) snapshot.mealCount else 0
        val rows = plateRows(options)
        val visible = meals.take(rows)
        val hidden = (mealCount - visible.size).coerceAtLeast(0)
        val atRisk = snapshot.streak > 0 && mealCount <= 0
        val tone = color(
            context,
            when {
                over -> R.color.widget_rose
                atRisk -> R.color.widget_coral
                mealCount <= 0 -> R.color.widget_accent_soft
                else -> R.color.widget_mint
            },
        )

        views.setTextViewText(
            R.id.widget_title,
            when {
                mealCount <= 0 && german -> "Heute"
                mealCount <= 0 -> "Today"
                german -> "Gegessen"
                else -> "Eaten"
            },
        )
        views.setTextColor(R.id.widget_title, tone)
        views.setTextViewText(
            R.id.widget_remaining,
            if (mealCount <= 0) {
                if (german) "Noch leer" else "Still open"
            } else {
                formatKcal(consumed, german)
            },
        )
        views.setTextColor(
            R.id.widget_remaining,
            color(context, if (over) R.color.widget_rose else R.color.widget_text),
        )
        views.setTextViewText(
            R.id.widget_label,
            when {
                mealCount <= 0 && german -> "ERSTER TELLER OFFEN"
                mealCount <= 0 -> "FIRST PLATE OPEN"
                german -> "KCAL HEUTE"
                else -> "KCAL TODAY"
            },
        )
        views.setTextColor(R.id.widget_label, tone)
        bindStreak(context, views, snapshot, atRisk)

        if (mealCount <= 0) {
            views.setViewVisibility(R.id.widget_progress, View.GONE)
            views.setViewVisibility(R.id.widget_progress_over, View.GONE)
            views.setViewVisibility(R.id.widget_used, View.GONE)
            views.setViewVisibility(R.id.widget_meals, View.GONE)
            views.setViewVisibility(R.id.widget_overflow, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_empty,
                if (german) {
                    "Der erste Teller macht den Tag."
                } else {
                    "The first plate starts the day."
                },
            )
        } else {
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            views.setViewVisibility(R.id.widget_meals, View.VISIBLE)
            views.setViewVisibility(R.id.widget_used, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_used,
                plateMeta(mealCount, remaining, over, german),
            )
            bindProgress(views, consumed, numbers.second, over)
            views.removeAllViews(R.id.widget_meals)
            visible.forEachIndexed { index, meal ->
                views.addView(R.id.widget_meals, bindMealRow(context, meal, index, german))
            }
            if (hidden > 0) {
                views.setViewVisibility(R.id.widget_overflow, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_overflow,
                    if (german) "+$hidden weitere" else "+$hidden more",
                )
            } else {
                views.setViewVisibility(R.id.widget_overflow, View.GONE)
            }
        }

        views.setTextViewText(
            R.id.widget_add,
            if (mealCount <= 0) {
                if (german) "+ Essen hinzufügen" else "+ Add food"
            } else if (german) {
                "+ Neu"
            } else {
                "+ New"
            },
        )
        views.setOnClickPendingIntent(R.id.widget_add, launch(context, ACTION_ADD, 51, "add"))
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, ACTION_OPEN, 50))
        return views
    }

    private fun bindMealRow(
        context: Context,
        meal: CalorieWidgetStore.MealLine,
        index: Int,
        german: Boolean,
    ): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.plate_meal_row)
        val name = meal.name.ifBlank { if (german) "Mahlzeit" else "Meal" }
        row.setTextViewText(R.id.widget_meal_name, name)
        row.setTextViewText(R.id.widget_meal_kcal, formatKcal(meal.kcal, german))
        if (meal.time.isBlank()) {
            row.setViewVisibility(R.id.widget_meal_time, View.GONE)
        } else {
            row.setViewVisibility(R.id.widget_meal_time, View.VISIBLE)
            row.setTextViewText(R.id.widget_meal_time, meal.time)
        }
        row.setInt(R.id.widget_meal_bar, "setColorFilter", plateSwatch(context, index))
        row.setOnClickPendingIntent(R.id.widget_meal_root, launch(context, ACTION_OPEN, 52 + index))
        return row
    }

    private fun plateMeta(mealCount: Int, remaining: Int, over: Boolean, german: Boolean): String {
        val plates = if (german) {
            if (mealCount == 1) "1 Teller" else "$mealCount Teller"
        } else {
            if (mealCount == 1) "1 plate" else "$mealCount plates"
        }
        val rest = formatKcal(Math.abs(remaining), german)
        return when {
            over && german -> "$plates · $rest drüber"
            over -> "$plates · $rest over"
            german -> "$plates · $rest übrig"
            else -> "$plates · $rest left"
        }
    }

    private fun plateRows(options: Bundle?): Int {
        val minH = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        return when {
            minH >= 380 -> 6
            minH >= 320 -> 5
            minH >= 250 -> 4
            minH > 0 -> 3
            else -> 4
        }
    }

    private fun plateSwatch(context: Context, index: Int): Int {
        val ids = intArrayOf(
            R.color.widget_accent_soft,
            R.color.widget_mint,
            R.color.widget_swatch_violet,
            R.color.widget_swatch_gold,
            R.color.widget_swatch_pink,
            R.color.widget_accent,
            R.color.widget_swatch_lilac,
            R.color.widget_swatch_sky,
        )
        return color(context, ids[index % ids.size])
    }

    private fun bindHero(
        context: Context,
        views: RemoteViews,
        snapshot: CalorieWidgetStore.Snapshot,
        remaining: Int,
        over: Boolean,
    ) {
        val german = snapshot.german
        val mealsToday = mealsToday(snapshot)
        val atRisk = snapshot.streak > 0 && mealsToday <= 0
        views.setTextViewText(
            R.id.widget_title,
            when {
                atRisk && german -> "Serie"
                atRisk -> "Streak"
                else -> eyebrow(snapshot.coachMood, german)
            },
        )
        views.setTextViewText(
            R.id.widget_remaining,
            formatKcal(Math.abs(remaining), german).let { if (over) "+$it" else it },
        )
        views.setTextViewText(
            R.id.widget_label,
            when {
                over && german -> "ÜBER DEM ZIEL"
                over -> "OVER BUDGET"
                german -> "KCAL ÜBRIG"
                else -> "KCAL LEFT"
            },
        )
        val tone = color(
            context,
            when {
                over -> R.color.widget_rose
                atRisk -> R.color.widget_coral
                snapshot.coachMood == "proteinPush" -> R.color.widget_coral
                snapshot.coachMood == "morningOpen" -> R.color.widget_accent_soft
                else -> R.color.widget_mint
            },
        )
        views.setTextColor(R.id.widget_title, tone)
        views.setTextColor(R.id.widget_remaining, if (over) color(context, R.color.widget_rose) else color(context, R.color.widget_text))
        views.setTextColor(R.id.widget_label, tone)
        bindStreak(context, views, snapshot, atRisk)
    }

    private fun bindStreak(
        context: Context,
        views: RemoteViews,
        snapshot: CalorieWidgetStore.Snapshot,
        atRisk: Boolean,
    ) {
        if (snapshot.streak <= 0) {
            views.setViewVisibility(R.id.widget_streak, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_streak, View.VISIBLE)
        views.setTextViewText(R.id.widget_streak, "🔥 ${snapshot.streak}")
        views.setTextColor(
            R.id.widget_streak,
            color(context, if (atRisk) R.color.widget_coral else R.color.widget_mint),
        )
    }

    private fun mealsToday(snapshot: CalorieWidgetStore.Snapshot): Int {
        val isToday = snapshot.dateKey.isEmpty() || snapshot.dateKey == todayDateKey()
        return if (isToday) snapshot.mealCount else 0
    }

    private fun bindProgress(views: RemoteViews, consumed: Int, budget: Int, over: Boolean) {
        val progress = if (budget <= 0) {
            0
        } else {
            ((consumed.toLong() * 1000L) / budget.toLong()).toInt().coerceIn(0, 1000)
        }
        if (over) {
            views.setViewVisibility(R.id.widget_progress, View.GONE)
            views.setViewVisibility(R.id.widget_progress_over, View.VISIBLE)
            views.setProgressBar(R.id.widget_progress_over, 1000, progress, false)
        } else {
            views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
            views.setViewVisibility(R.id.widget_progress_over, View.GONE)
            views.setProgressBar(R.id.widget_progress, 1000, progress, false)
        }
    }

    private fun bindActions(
        context: Context,
        views: RemoteViews,
        snapshot: CalorieWidgetStore.Snapshot,
        compact: Boolean,
    ) {
        views.setTextViewText(
            R.id.widget_add,
            if (snapshot.favorites.isEmpty()) {
                if (snapshot.german) "+ Essen hinzufügen" else "+ Add food"
            } else if (compact) {
                if (snapshot.german) "+ Neu" else "+ New"
            } else {
                if (snapshot.german) "+ Neu" else "+ New"
            },
        )
        views.setOnClickPendingIntent(R.id.widget_add, launch(context, ACTION_ADD, 1, "add"))
        bindFavorite(context, views, R.id.widget_fav_0, snapshot.favorites.getOrNull(0), 10)
        bindFavorite(context, views, R.id.widget_fav_1, snapshot.favorites.getOrNull(1), 11)
    }

    private fun bindFavorite(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        chip: CalorieWidgetStore.FavoriteChip?,
        requestCode: Int,
    ) {
        if (chip == null) {
            views.setViewVisibility(viewId, View.GONE)
            return
        }
        views.setViewVisibility(viewId, View.VISIBLE)
        views.setTextViewText(viewId, chip.name)
        views.setOnClickPendingIntent(
            viewId,
            launch(context, ACTION_FAVORITE, requestCode, "favorite", chip.id),
        )
    }

    private fun usedLine(consumed: Int, budget: Int, snapshot: CalorieWidgetStore.Snapshot, german: Boolean): String {
        val line = snapshot.coachLine
        if (line.isNotBlank()) return line
        val used = "${formatKcal(consumed, german)} / ${formatKcal(budget, german)} kcal"
        if (snapshot.mealCount <= 0) {
            return if (german) "$used · noch nichts" else "$used · nothing yet"
        }
        return used
    }

    private fun fallbackLine(remaining: Int, over: Boolean, german: Boolean): String {
        return when {
            over && german -> "${formatKcal(remaining, true)} kcal drüber. Morgen ist ein neuer Tag."
            over -> "${formatKcal(remaining, false)} kcal over. Tomorrow is a new day."
            german -> "Noch ${formatKcal(remaining, true)} kcal. Ein Tipp genügt."
            else -> "${formatKcal(remaining, false)} kcal left. One tap is enough."
        }
    }

    private fun eyebrow(mood: String, german: Boolean): String {
        return when (mood) {
            "morningOpen" -> if (german) "Morgen" else "Morning"
            "proteinPush" -> "Protein"
            "dinner", "latePlate" -> if (german) "Abend" else "Evening"
            else -> if (german) "Heute" else "Today"
        }
    }

    private fun formatKcal(value: Int, german: Boolean): String {
        val locale = if (german) Locale.GERMAN else Locale.US
        return NumberFormat.getIntegerInstance(locale).format(Math.abs(value))
    }

    private fun todayDateKey(): String {
        val calendar = Calendar.getInstance()
        return "${calendar.get(Calendar.DAY_OF_MONTH)}.${calendar.get(Calendar.MONTH) + 1}.${calendar.get(Calendar.YEAR)}"
    }

    @Suppress("DEPRECATION")
    fun color(context: Context, id: Int): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.getColor(id)
        } else {
            context.resources.getColor(id)
        }
    }

    fun launch(
        context: Context,
        intentAction: String,
        requestCode: Int,
        widgetAction: String? = null,
        favoriteId: String? = null,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = intentAction
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (widgetAction != null) putExtra(EXTRA_ACTION, widgetAction)
            if (!favoriteId.isNullOrEmpty()) putExtra(EXTRA_FAVORITE_ID, favoriteId)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }
}
