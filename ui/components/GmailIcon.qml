import QtQuick
import qs.Commons
import qs.Ui

// The mark, drawn rather than rasterised from an SVG: the bar slot is about
// 16px and Qt's SVG renderer smears strokes at that size.
//
// The fold is a plain V; the heart seal sitting on its point is what sets
// this mark apart from every other envelope in the bar. The frame and the fold
// follow the bar foreground. The heart follows the theme accent.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color markColor: color
  property color badgeColor: Color.urgent
  // A dot, not a count: the bar says "something arrived", the tooltip says
  // how much, and the window says what.
  property bool dot: false
  property bool crossed: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  onColorChanged: envelope.requestPaint()
  onMarkColorChanged: envelope.requestPaint()
  onIconSizeChanged: envelope.requestPaint()

  Canvas {
    id: envelope
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width
      var h = height
      if (w <= 0 || h <= 0) return

      // The body is inset vertically so a wide-but-short envelope keeps the
      // 3:2 proportion a letter actually has.
      var left = w * 0.06
      var right = w * 0.94
      var top = h * 0.20
      var bottom = h * 0.80
      var stroke = Math.max(1, w * 0.085)

      ctx.strokeStyle = root.color
      ctx.lineWidth = stroke
      ctx.lineJoin = "round"
      ctx.lineCap = "round"

      ctx.beginPath()
      ctx.rect(left, top, right - left, bottom - top)
      ctx.stroke()

      // The fold and the seal come from the mark's 64-unit artwork
      // (ui/assets/maitri-mail.svg), whose frame spans x 5..59 and y 13..51.
      var sx = (right - left) / 54
      var sy = (bottom - top) / 38
      function x(u) { return left + (u - 5) * sx }
      function y(v) { return top + (v - 13) * sy }

      ctx.beginPath()
      ctx.moveTo(x(10), y(19))
      ctx.lineTo(x(32), y(35))
      ctx.lineTo(x(54), y(19))
      ctx.stroke()

      ctx.fillStyle = root.markColor
      ctx.strokeStyle = root.markColor
      ctx.lineWidth = Math.max(0.5, 2 * sx)
      ctx.beginPath()
      ctx.moveTo(x(32.00), y(32.97))
      ctx.bezierCurveTo(x(30.88), y(30.07), x(28.64), y(28.95), x(27.53), y(28.95))
      ctx.bezierCurveTo(x(24.39), y(28.95), x(22.61), y(32.97), x(25.74), y(36.11))
      ctx.lineTo(x(32.00), y(42.37))
      ctx.lineTo(x(38.26), y(36.11))
      ctx.bezierCurveTo(x(41.39), y(32.97), x(39.61), y(28.95), x(36.47), y(28.95))
      ctx.bezierCurveTo(x(35.36), y(28.95), x(33.12), y(30.07), x(32.00), y(32.97))
      ctx.closePath()
      ctx.fill()
      ctx.stroke()
    }
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.22
    height: Math.max(2, parent.height * 0.13)
    radius: height / 2
    color: root.color
    rotation: -45
  }

  // On the corner rather than beside the icon, so the bar slot stays one
  // square whether or not anything is waiting.
  BorderSurface {
    visible: root.dot
    width: Math.max(Style.space(5), parent.width * 0.34)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.rightMargin: -parent.width * 0.06
    anchors.top: parent.top
    anchors.topMargin: -parent.height * 0.04
    borderSpec: Border.flat(Color.popups.background, 1)
  }
}
