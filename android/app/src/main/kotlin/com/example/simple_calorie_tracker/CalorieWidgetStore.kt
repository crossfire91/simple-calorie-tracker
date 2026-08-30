package com.example.simple_calorie_tracker

import android.content.Context

object CalorieWidgetStore {
    private const val PREFS = "calorie_home_widget"
    private const val KEY_CONSUMED = "consumedKcal"
    private const val KEY_BUDGET = "budgetKcal"
    private const val KEY_DATE = "dateKey"
    private const val KEY_LANG = "lang"
    private const val KEY_MEALS = "mealCount"
    private const val KEY_FAV_COUNT = "favCount"
    private const val KEY_LINE_DE = "coachLineDe"
    private const val KEY_LINE_EN = "coachLineEn"
    private const val KEY_MOOD = "coachMood"
    private const val KEY_PROTEIN_G = "proteinGrams"
    private const val KEY_PROTEIN_T = "proteinTarget"
    private const val KEY_PROTEIN_NAME = "proteinName"
    private const val KEY_PROTEIN_ID = "proteinFavoriteId"
    private const val KEY_STREAK = "streak"
    private const val KEY_MEAL_LINES = "mealLineCount"
    private const val MEAL_LINE_CAP = 8

    fun save(
        context: Context,
        consumedKcal: Int,
        budgetKcal: Int,
        dateKey: String,
        lang: String,
        mealCount: Int,
        favorites: List<FavoriteChip> = emptyList(),
        coachLineDe: String = "",
        coachLineEn: String = "",
        coachMood: String = "nextPlate",
        proteinGrams: Int = 0,
        proteinTarget: Int = 90,
        proteinName: String = "",
        proteinFavoriteId: String = "",
        streak: Int = 0,
        meals: List<MealLine> = emptyList(),
    ) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        editor
            .putInt(KEY_CONSUMED, consumedKcal)
            .putInt(KEY_BUDGET, budgetKcal)
            .putString(KEY_DATE, dateKey)
            .putString(KEY_LANG, lang)
            .putInt(KEY_MEALS, mealCount)
            .putString(KEY_LINE_DE, coachLineDe)
            .putString(KEY_LINE_EN, coachLineEn)
            .putString(KEY_MOOD, coachMood)
            .putInt(KEY_PROTEIN_G, proteinGrams)
            .putInt(KEY_PROTEIN_T, proteinTarget)
            .putString(KEY_PROTEIN_NAME, proteinName)
            .putString(KEY_PROTEIN_ID, proteinFavoriteId)
            .putInt(KEY_STREAK, streak)
        val lines = meals.take(MEAL_LINE_CAP)
        editor.putInt(KEY_MEAL_LINES, lines.size)
        for (index in 0 until MEAL_LINE_CAP) {
            val line = lines.getOrNull(index)
            editor.putString("meal_${index}_name", line?.name ?: "")
            editor.putInt("meal_${index}_kcal", line?.kcal ?: 0)
            editor.putString("meal_${index}_time", line?.time ?: "")
        }
        val chips = favorites.take(2)
        editor.putInt(KEY_FAV_COUNT, chips.size)
        for (index in 0 until 2) {
            val chip = chips.getOrNull(index)
            editor.putString("fav_${index}_id", chip?.id ?: "")
            editor.putString("fav_${index}_name", chip?.name ?: "")
            editor.putInt("fav_${index}_kcal", chip?.kcal ?: 0)
        }
        editor.apply()
    }

    fun saveLang(context: Context, lang: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LANG, lang)
            .apply()
    }

    fun snapshot(context: Context): Snapshot {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val count = prefs.getInt(KEY_FAV_COUNT, 0).coerceIn(0, 2)
        val favorites = (0 until count).map { index ->
            FavoriteChip(
                id = prefs.getString("fav_${index}_id", "") ?: "",
                name = prefs.getString("fav_${index}_name", "") ?: "",
                kcal = prefs.getInt("fav_${index}_kcal", 0),
            )
        }.filter { it.id.isNotEmpty() && it.name.isNotEmpty() }
        val lineCount = prefs.getInt(KEY_MEAL_LINES, 0).coerceIn(0, MEAL_LINE_CAP)
        val meals = (0 until lineCount).map { index ->
            MealLine(
                name = prefs.getString("meal_${index}_name", "") ?: "",
                kcal = prefs.getInt("meal_${index}_kcal", 0),
                time = prefs.getString("meal_${index}_time", "") ?: "",
            )
        }
        return Snapshot(
            consumedKcal = prefs.getInt(KEY_CONSUMED, 0),
            budgetKcal = prefs.getInt(KEY_BUDGET, 2500),
            dateKey = prefs.getString(KEY_DATE, "") ?: "",
            lang = prefs.getString(KEY_LANG, "de") ?: "de",
            mealCount = prefs.getInt(KEY_MEALS, 0),
            favorites = favorites,
            coachLineDe = prefs.getString(KEY_LINE_DE, "") ?: "",
            coachLineEn = prefs.getString(KEY_LINE_EN, "") ?: "",
            coachMood = prefs.getString(KEY_MOOD, "nextPlate") ?: "nextPlate",
            proteinGrams = prefs.getInt(KEY_PROTEIN_G, 0),
            proteinTarget = prefs.getInt(KEY_PROTEIN_T, 90),
            proteinName = prefs.getString(KEY_PROTEIN_NAME, "") ?: "",
            proteinFavoriteId = prefs.getString(KEY_PROTEIN_ID, "") ?: "",
            streak = prefs.getInt(KEY_STREAK, 0),
            meals = meals,
        )
    }

    data class FavoriteChip(
        val id: String,
        val name: String,
        val kcal: Int,
    )

    data class MealLine(
        val name: String,
        val kcal: Int,
        val time: String,
    )

    data class Snapshot(
        val consumedKcal: Int,
        val budgetKcal: Int,
        val dateKey: String,
        val lang: String,
        val mealCount: Int,
        val favorites: List<FavoriteChip> = emptyList(),
        val coachLineDe: String = "",
        val coachLineEn: String = "",
        val coachMood: String = "nextPlate",
        val proteinGrams: Int = 0,
        val proteinTarget: Int = 90,
        val proteinName: String = "",
        val proteinFavoriteId: String = "",
        val streak: Int = 0,
        val meals: List<MealLine> = emptyList(),
    ) {
        val german: Boolean get() = lang != "en"
        val coachLine: String get() = if (german) coachLineDe else coachLineEn
    }
}
