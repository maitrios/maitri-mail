import QtQuick 2.15
import QtTest 1.3
import qs.Commons
import "../../components" as MaitriMail
import "../../message/Html.js" as Html

// A right-click on an address line in the reader's header opens the address
// menu. The addresses reach it through the reader's `var` signal, which on
// Qt 6.12 turns the list into a sequence.
Item {
  width: 900
  height: 600

  readonly property string senderHtml: '<p>Person 1 moved 4 cards.</p>'

  readonly property var rendered: Html.sanitize(senderHtml, ({ withReader: true }))

  QtObject {
    id: mailService

    property string selectedId: "message-9"
    property var selectedMessage: ({
      id: "message-9",
      subject: "Activity on Sprint board",
      from: ({ display: "Boards", email: "boards@example.com" }),
      to: [({ display: "Reader", email: "reader@example.com" })],
      cc: [({ display: "Other", email: "other@example.com" })],
      fullTime: "24 August 2026",
      starred: false
    })
    property bool detailLoading: false
    property bool detailPainted: true
    property bool selectedHasHtml: rendered.html !== ""
    property var selectedDocument: rendered.document
    property var selectedReaderDocument: rendered.reader.document
    property bool selectedReaderTooHeavy: rendered.reader.tooHeavy
    property bool selectedReaderEmpty: rendered.reader.empty
    property int selectedRemoteImages: rendered.remoteImages
    property bool remoteImagesAllowed: false
    property bool selectedTooHeavy: rendered.tooHeavy
    property string unsubscribeLabel: ""
    property string unsubscribeDetail: ""
    property bool unsubscribing: false
    property var selectedBody: ({ text: "Person 1 moved 4 cards.", source: "html" })
    property var selectedImages: []
    property var selectedInvite: null
    property string selectedResponse: ""
    property bool canRespondToInvite: false
    property bool rsvpSending: false
    property bool canArchive: true
    property bool canOpenOnWeb: false
    property var selectedAttachments: []

    function getMessage() {}
    function showRemoteImages() {}
    function copyText(text) { return true }
    function openExternal(url) { return true }
  }

  MaitriMail.MessageReader {
    id: reader
    width: 900
    height: 600
    service: mailService
    textColor: Qt.rgba(1, 1, 1, 1)
    backgroundColor: Qt.rgba(0.06, 0.06, 0.06, 1)
    accentColor: Qt.rgba(1, 0.5, 0, 1)
    linkColor: Qt.rgba(0.3, 0.7, 1, 1)
    dimColor: Qt.rgba(0.67, 0.67, 0.67, 1)
    popupBackgroundColor: Qt.rgba(0.13, 0.13, 0.13, 1)
    popupBorderColor: Qt.rgba(0.47, 0.47, 0.47, 1)
    leadingBoundaryOverlap: 0
    dimmerColor: Qt.rgba(0.47, 0.47, 0.47, 1)
    panelFontFamily: "monospace"
    bodyMode: "reader"
    onBodyModeRequested: function(mode) { reader.bodyMode = mode }
    onAddressMenuRequested: function(addresses, sceneX, sceneY) { addressMenu.openAt(addresses, sceneX, sceneY) }
  }

  MaitriMail.AddressMenu {
    id: addressMenu
    anchors.fill: parent
    textColor: Qt.rgba(1, 1, 1, 1)
    dimColor: Qt.rgba(0.67, 0.67, 0.67, 1)
    popupBackgroundColor: Qt.rgba(0.13, 0.13, 0.13, 1)
    popupBorderColor: Qt.rgba(0.47, 0.47, 0.47, 1)
    panelFontFamily: "monospace"
  }

  TestCase {
    name: "AddressMenu"
    when: windowShown

    function lineShowing(text) {
      var found = null
      function walk(item) {
        if (!item || found) return
        if (item.text !== undefined && String(item.text).indexOf(text) >= 0 && item.width > 0) { found = item; return }
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) walk(kids[i])
      }
      walk(reader)
      verify(found, "the reader shows " + text)
      return found
    }

    function rightClick(line) {
      mouseClick(line, 30, line.height / 2, Qt.RightButton)
      tryVerify(function() { return addressMenu.opened }, 1000, "the address menu opens")
    }

    function cleanup() {
      addressMenu.close()
      tryVerify(function() { return !addressMenu.opened }, 1000)
    }

    function test_a_right_click_on_the_sender_offers_its_address() {
      rightClick(lineShowing("boards@example.com"))
      compare(addressMenu.choosing, false)
      compare(addressMenu.chosen, "boards@example.com")
      compare(addressMenu.addresses[0].name, "Boards")
    }

    function test_a_right_click_on_the_recipients_asks_which_one() {
      rightClick(lineShowing("· 24 August 2026"))
      compare(addressMenu.choosing, true)
      compare(addressMenu.addresses.length, 2)
      compare(addressMenu.addresses[1].email, "other@example.com")
    }

    function test_a_list_handed_over_directly_opens_the_menu() {
      addressMenu.openAt([{ name: "A", email: "a@example.com" }], 10, 10)
      tryVerify(function() { return addressMenu.opened }, 1000)
      compare(addressMenu.chosen, "a@example.com")
    }
  }
}
