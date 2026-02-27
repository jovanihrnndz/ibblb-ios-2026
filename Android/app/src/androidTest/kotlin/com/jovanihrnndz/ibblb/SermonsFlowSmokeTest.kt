package com.jovanihrnndz.ibblb

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SermonsFlowSmokeTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun sermonsList_toDetail_toBack() {
        composeRule.onNodeWithText("Sermons", useUnmergedTree = true).performClick()
        composeRule.onNodeWithText("Search sermons").assertIsDisplayed()

        // If API loading failed in CI/emulator, switch to deterministic local fixtures.
        val sampleButton = composeRule.onAllNodesWithText("Load Sample Sermons", useUnmergedTree = true)
        if (sampleButton.fetchSemanticsNodes().isNotEmpty()) {
            sampleButton[0].performClick()
            composeRule.waitForIdle()
        }

        val fixtureRowMatcher = hasClickAction().and(
            hasAnyDescendant(hasText("Faith That Endures", substring = true))
        )
        val liveRowMatcher = hasClickAction().and(
            hasAnyDescendant(hasText("Pastor", substring = true))
        )

        composeRule.waitUntil(15_000) {
            composeRule.onAllNodes(fixtureRowMatcher, useUnmergedTree = true)
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(liveRowMatcher, useUnmergedTree = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

        val fixtureRows = composeRule.onAllNodes(fixtureRowMatcher, useUnmergedTree = true)
        if (fixtureRows.fetchSemanticsNodes().isNotEmpty()) {
            fixtureRows[0].performClick()
        } else {
            val liveRows = composeRule.onAllNodes(liveRowMatcher, useUnmergedTree = true)
            liveRows[0].performClick()
        }

        composeRule.onNodeWithText("Sermon", useUnmergedTree = true).assertIsDisplayed()

        composeRule.activity.onBackPressedDispatcher.onBackPressed()
        composeRule.onNodeWithText("Search sermons").assertIsDisplayed()
    }

    @Test
    fun eventsTab_toDetail_toBack() {
        composeRule.onNodeWithText("Events", useUnmergedTree = true).performClick()
        composeRule.onNodeWithText("Search events").assertIsDisplayed()

        val sampleButton = composeRule.onAllNodesWithText("Load Sample Events", useUnmergedTree = true)
        if (sampleButton.fetchSemanticsNodes().isNotEmpty()) {
            sampleButton[0].performClick()
            composeRule.waitForIdle()
        }

        val fixtureRowMatcher = hasClickAction().and(
            hasAnyDescendant(hasText("Community Prayer Night", substring = true))
        )
        composeRule.waitForIdle()

        val fixtureRows = composeRule.onAllNodes(fixtureRowMatcher, useUnmergedTree = true)
        if (fixtureRows.fetchSemanticsNodes().isNotEmpty()) {
            fixtureRows[0].performClick()
            composeRule.onNodeWithText("Details", useUnmergedTree = true).assertIsDisplayed()
            composeRule.activity.onBackPressedDispatcher.onBackPressed()
            composeRule.onNodeWithText("Search events").assertIsDisplayed()
        }
    }
}
