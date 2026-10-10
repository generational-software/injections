import QtQuick
import QtQuick.Shapes

// Flat syringe, turned so the needle points up and to the right.
// The root size is the rotated bounds, so the mark does not spill onto
// the dose count beside it.
Item {
  id: root

  property real iconSize: 15
  property color color: "#ffffff"
  property real angle: -44

  readonly property real bodyLength: iconSize
  readonly property real bodyThickness: Math.max(6, iconSize * 0.42)
  readonly property real radians: angle * Math.PI / 180

  implicitWidth: bodyLength * Math.abs(Math.cos(radians)) + bodyThickness * Math.abs(Math.sin(radians))
  implicitHeight: bodyLength * Math.abs(Math.sin(radians)) + bodyThickness * Math.abs(Math.cos(radians))
  width: implicitWidth
  height: implicitHeight

  Item {
    id: body
    anchors.centerIn: parent
    width: root.bodyLength
    height: root.bodyThickness
    rotation: root.angle
    layer.enabled: true
    layer.smooth: true
    layer.samples: 4

    readonly property color ink: root.color
    readonly property real stroke: Math.max(1.15, height * 0.14)

    Rectangle {
      // Thumb pad at the plunger end.
      width: body.height * 0.36
      height: body.height * 0.58
      radius: width * 0.34
      x: 0
      y: (body.height - height) / 2
      color: body.ink
    }

    Rectangle {
      x: body.height * 0.30
      y: (body.height - height) / 2
      width: body.width * 0.14
      height: body.stroke
      radius: height / 2
      color: body.ink
    }

    Rectangle {
      // Finger flange.
      x: body.width * 0.20
      y: 0
      width: body.stroke
      height: body.height
      radius: width * 0.45
      color: body.ink
    }

    Rectangle {
      x: body.width * 0.29
      y: body.height * 0.14
      width: body.width * 0.40
      height: body.height * 0.72
      radius: height * 0.28
      color: "transparent"
      border.color: body.ink
      border.width: body.stroke
    }

    Rectangle {
      // Dose sitting in the barrel.
      x: body.width * 0.48
      y: (body.height - height) / 2
      width: body.width * 0.13
      height: body.height * 0.26
      radius: height / 2
      color: body.ink
    }

    Rectangle {
      x: body.width * 0.69
      y: body.height * 0.28
      width: body.width * 0.07
      height: body.height * 0.44
      radius: width * 0.35
      color: body.ink
    }

    Rectangle {
      x: body.width * 0.75
      y: (body.height - height) / 2
      width: body.width * 0.17
      height: Math.max(1.1, body.stroke * 0.85)
      color: body.ink
    }

    Shape {
      id: tip
      x: body.width * 0.91
      width: body.width * 0.09
      height: body.height * 0.34
      anchors.verticalCenter: parent.verticalCenter
      antialiasing: true

      ShapePath {
        fillColor: body.ink
        strokeWidth: 0
        startX: 0
        startY: 0
        PathLine { x: tip.width; y: tip.height / 2 }
        PathLine { x: 0; y: tip.height }
        PathLine { x: 0; y: 0 }
      }
    }
  }
}
