package com.example.simple_calorie_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class CalorieWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        WidgetHub.refresh(context, CalorieWidgetProvider::class.java)
    }

    companion object {
        const val EXTRA_ACTION = WidgetHub.EXTRA_ACTION
        const val EXTRA_FAVORITE_ID = WidgetHub.EXTRA_FAVORITE_ID

        fun refreshAll(context: Context) {
            WidgetHub.refreshAll(context)
        }
    }
}
