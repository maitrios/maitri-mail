import QtQuick
import qs.Commons

Item {
  id: root
  required property color foreground
  required property color accent
  property bool animated: true
  property real progress: 0
  property real entrance: 0
  property real sealScale: 0.6
  property real sealOpacity: 0
  property bool drawingReady: false
  implicitWidth: Style.space(64)
  implicitHeight: implicitWidth
  clip: true

  function enter() {
    drawing.stop()
    arrival.stop()
    drawingReady = false
    progress = animated ? 0 : 1
    sealScale = animated ? 0.6 : 1
    sealOpacity = animated ? 0 : 1
    entrance = animated ? 0 : 1
    if (visible && animated) arrival.restart()
  }
  Component.onCompleted: enter()
  onVisibleChanged: enter()
  onAnimatedChanged: enter()

  // Follow the mark's V fold from its left end at constant speed.
  function tracePoints(amount) {
    var points = [[10, 19], [32, 35], [54, 19]]
    var remaining = Math.max(0, Math.min(1, amount)) * 2 * Math.sqrt(740)
    var path = [[10, 19]]
    for (var i = 1; i < points.length && remaining > 0; i++) {
      var a = points[i - 1]
      var b = points[i]
      var distance = Math.sqrt(Math.pow(b[0] - a[0], 2) + Math.pow(b[1] - a[1], 2))
      var fraction = Math.min(1, remaining / distance)
      path.push([a[0] + (b[0] - a[0]) * fraction,
        a[1] + (b[1] - a[1]) * fraction])
      remaining -= distance
    }
    return path
  }

  Item {
    width: root.width
    height: root.height
    y: root.height * 0.4 * (1 - root.entrance)
    opacity: root.entrance
    // A single rounded border avoids overlapping tessellated arc joins.
    Rectangle {
      x: root.width * 2.5 / 64
      y: root.height * 10.5 / 64
      width: root.width * 59 / 64
      height: root.height * 43 / 64
      radius: root.width * 7.5 / 64
      color: "transparent"
      border.color: root.foreground
      border.width: root.width * 5 / 64
      antialiasing: true
    }
    Canvas {
      id: fold
      anchors.fill: parent
      antialiasing: true
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        ctx.scale(width / 64, height / 64)
        ctx.lineWidth = 5
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        // Canvas strokes a joined path once, including its translucent base.
        // Shape's tessellated stroke overlapped at joins and left bright seams.
        for (var pass = 0; pass < 2; pass++) {
          var amount = pass === 0 ? 1 : root.progress
          if (amount <= 0) continue
          var points = root.tracePoints(amount)
          ctx.strokeStyle = pass === 0 ? Qt.alpha(root.foreground, 0.2) : root.foreground
          ctx.beginPath()
          ctx.moveTo(10, 19)
          for (var i = 1; i < points.length; i++)
            ctx.lineTo(points[i][0], points[i][1])
          ctx.stroke()
        }
      }
    }
    Canvas {
      id: seal
      anchors.fill: parent
      antialiasing: true
      opacity: root.sealOpacity
      transform: Scale {
        origin.x: seal.width * 32 / 64
        origin.y: seal.height * 35.66 / 64
        xScale: root.sealScale
        yScale: root.sealScale
      }
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        ctx.scale(width / 64, height / 64)
        ctx.fillStyle = root.accent
        ctx.strokeStyle = root.accent
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(32.00, 32.97)
        ctx.bezierCurveTo(30.88, 30.07, 28.64, 28.95, 27.53, 28.95)
        ctx.bezierCurveTo(24.39, 28.95, 22.61, 32.97, 25.74, 36.11)
        ctx.lineTo(32.00, 42.37)
        ctx.lineTo(38.26, 36.11)
        ctx.bezierCurveTo(41.39, 32.97, 39.61, 28.95, 36.47, 28.95)
        ctx.bezierCurveTo(35.36, 28.95, 33.12, 30.07, 32.00, 32.97)
        ctx.closePath()
        ctx.fill()
        ctx.stroke()
      }
    }
  }

  onProgressChanged: fold.requestPaint()
  onForegroundChanged: fold.requestPaint()
  onAccentChanged: seal.requestPaint()

  SequentialAnimation {
    id: arrival
    NumberAnimation {
      target: root
      property: "entrance"
      from: 0
      to: 1
      duration: 650
      easing.type: Easing.OutCubic
    }
    PauseAnimation { duration: 500 }
    onFinished: root.drawingReady = true
  }

  SequentialAnimation {
    id: drawing
    running: root.visible && root.animated && root.drawingReady
    loops: Animation.Infinite
    PropertyAction { target: root; property: "sealOpacity"; value: 0 }
    PropertyAction { target: root; property: "sealScale"; value: 0.6 }
    NumberAnimation {
      target: root
      property: "progress"
      from: 0
      to: 1
      duration: 1100
      easing.type: Easing.Linear
    }
    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "sealScale"
        from: 0.6
        to: 1
        duration: 320
        easing.type: Easing.OutBack
      }
      NumberAnimation {
        target: root
        property: "sealOpacity"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
      }
    }
    PauseAnimation { duration: 2500 }
  }
}
