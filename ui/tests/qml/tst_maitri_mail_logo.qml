import QtQuick
import QtTest
import "../../components" as Components

Item {
  width: 180
  height: 140
  Components.MaitriMailLogo {
    id: logo
    anchors.centerIn: parent
    foreground: Qt.rgba(0.6, 0.6, 0.6, 1)
    accent: Qt.rgba(0.9, 0.25, 0.25, 1)
  }
  Components.MaitriMailLogo {
    id: still
    animated: false
    visible: false
    foreground: Qt.rgba(0.6, 0.6, 0.6, 1)
    accent: Qt.rgba(0.9, 0.25, 0.25, 1)
  }
  TestCase {
    name: "MaitriMailLogo"
    when: windowShown
    function test_enter_once_then_trace_the_fold_land_the_seal_and_pause() {
      logo.enter()
      compare(logo.entrance, 0)
      compare(logo.progress, 0)
      compare(logo.sealOpacity, 0)
      tryCompare(logo, "entrance", 1, 1200)
      compare(logo.progress, 0)
      wait(300)
      compare(logo.progress, 0, "pause before the first stroke")
      tryVerify(function() { return logo.progress > 0 }, 500)
      wait(150)
      verify(logo.progress < 0.5, "the fold is traced, not drawn at once")
      compare(logo.sealOpacity, 0, "the heart waits for the fold")
      tryCompare(logo, "progress", 1, 1600)
      tryCompare(logo, "sealOpacity", 1, 600)
      tryCompare(logo, "sealScale", 1, 600)
      wait(2100)
      compare(logo.progress, 1, "the finished mark holds through the pause")
      compare(logo.sealOpacity, 1)
      tryVerify(function() { return logo.progress < 1 }, 900)
      compare(logo.sealOpacity, 0, "the loop starts over without the heart")
      compare(logo.entrance, 1, "drawing loop must not repeat the entrance")
      logo.visible = false
      wait(50)
      compare(logo.progress, 0)
      compare(logo.entrance, 0)
      compare(logo.sealOpacity, 0)
      logo.visible = true
      tryCompare(logo, "entrance", 1, 1200)
    }
    function test_seal_lands_with_an_overshoot() {
      logo.enter()
      tryCompare(logo, "progress", 1, 3500)
      var largest = 0
      for (var i = 0; i < 160; i++) {
        largest = Math.max(largest, logo.sealScale)
        if (logo.sealScale === 1 && largest > 1) break
        wait(5)
      }
      verify(largest > 1, "OutBack overshoots before the heart settles")
      tryCompare(logo, "sealScale", 1, 600)
    }
    function test_trace_starts_at_the_left_of_the_fold_and_keeps_the_v() {
      compare(logo.tracePoints(0), [[10, 19]])
      compare(logo.tracePoints(0.5), [[10, 19], [32, 35]])
      compare(logo.tracePoints(1), [[10, 19], [32, 35], [54, 19]])
      var quarter = logo.tracePoints(0.25)
      compare(quarter.length, 2)
      fuzzyCompare(quarter[1][0], 21, 0.001)
      fuzzyCompare(quarter[1][1], 27, 0.001)
    }
    function test_a_still_logo_shows_the_whole_mark() {
      compare(still.entrance, 1)
      compare(still.progress, 1)
      compare(still.sealOpacity, 1)
      compare(still.sealScale, 1)
    }
  }
}
