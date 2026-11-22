package com.doyourwork.app.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import com.doyourwork.app.ui.DoYourWorkTheme
import com.doyourwork.app.ui.Themes
import kotlinx.coroutines.launch

/**
 * Picks whose card a Today or Dares widget shows, when it's added or edited. Optional: a widget
 * nobody set shows this phone's player, or the first on the scoreboard.
 */
class WidgetPlayerActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Backing out leaves the widget as it was (or not added, if it's new).
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()
        Themes.load(this)
        val players = WidgetWriter.read(this)?.players.orEmpty()

        setContent {
            DoYourWorkTheme {
                val scope = rememberCoroutineScope()
                val t = Themes.current
                Column(Modifier.fillMaxSize().background(t.bg).safeDrawingPadding().verticalScroll(rememberScrollState())) {
                    Text("Whose card?", color = t.text, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(20.dp))
                    if (players.isEmpty()) {
                        Text("Open DOYOURWORK and set up your family first.", color = t.muted, modifier = Modifier.padding(horizontal = 20.dp))
                    }
                    players.forEachIndexed { i, p ->
                        Text(p.name, color = t.heat.ink, fontSize = 20.sp, fontWeight = FontWeight.Bold,
                            modifier = Modifier.fillMaxWidth().background(t.heat.band(i, players.size)).clickable {
                                scope.launch {
                                    val id = GlanceAppWidgetManager(this@WidgetPlayerActivity).getGlanceIdBy(widgetId)
                                    updateAppWidgetState(this@WidgetPlayerActivity, id) { it[PLAYER] = p.id }
                                    refreshWidgets(this@WidgetPlayerActivity)
                                    setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                                    finish()
                                }
                            }.padding(horizontal = 20.dp, vertical = 18.dp))
                    }
                    Text("Shows this phone's player if you skip this.", color = Color.Gray, fontSize = 13.sp, modifier = Modifier.padding(20.dp))
                }
            }
        }
    }
}
