import QtQuick
import QtTest
import "../../components" as Views
import "../../calendar/Calendar.js" as Calendar

// An event reaches the detail through the week view's `eventActivated(var
// event)` or an agenda row's `modelData`, and the composer through the
// detail's and the view's `editRequested(string, var event)`, wired the way
// App.qml wires them. On Qt 6.12 each of those turns the event's `attendees`
// into a sequence.
Item {
  width: 1000
  height: 700
  SystemPalette { id: palette }
  QtObject {
    id: serviceFixture
    property bool backendCanGoogleCalendars: false
    property string calendarPalettePath: ""
    property var recipientContacts: []
    function refreshRecipientContacts() {}
  }
  QtObject {
    id: fixture
    property var service: serviceFixture
    property var source: ({id:"google:me@example.test",kind:"google",accountId:"me@example.test",calendarId:"primary",readOnly:false,colorKey:"accent"})
    property var availableSources: ({sources:[source]})
    property var writableSourceGroups: [{id:source.id,providerLabel:"Google",accountLabel:"me@example.test",
      calendars:[{id:source.id,name:"me@example.test",colorKey:"accent",kind:"google"}]}]
    property var events: []
    property var pending: []
    property var updates: []
    property bool sourcesLoaded: false
    property bool loading: false
    property bool clockRunning: false
    property bool creatingEvent: false
    property bool eventWriting: false
    property bool composerHeld: false
    property string accountId: "me@example.test"
    property double nowMs: Date.now()
    property string lastError: ""
    property string lastErrorKind: ""
    signal eventCreated(bool ok, string error)
    signal eventUpdated(bool ok, string error)
    signal composeRequested(var prefill)
    signal composeEnded()
    function findSource(id) { return id === source.id ? source : null }
    function colorKeyFor(id) { return "accent" }
    function refresh(start, end) {}
    function nativeRequest(source, operation, fields, callback) {
      pending = pending.concat([{operation:operation,fields:fields,callback:callback}])
    }
    function createEvent(sourceId, fields) { return false }
    // The two library calls CalendarController.updateEvent makes before it
    // writes a Google event.
    function updateEvent(sourceId, event, fields) {
      var built = Calendar.updateEvent(fields, event, Date.now())
      updates = updates.concat([{event:event, fields:fields,
        options: built.ok ? Calendar.googleOptions(built.google, fields, findSource(sourceId), event) : built}])
      return true
    }
  }
  Views.CalendarView {
    id: view
    anchors.fill: parent
    controller: fixture
    textColor: palette.text
    backgroundColor: palette.base
    accentColor: palette.highlight
    urgentColor: palette.highlight
    dimColor: palette.mid
    calendarBorderColor: palette.mid
    calendarTodayBackgroundColor: palette.alternateBase
    calendarBorderWidth: 1
    panelFontFamily: "sans-serif"
    onEditRequested: function(sourceId, event) { composer.beginEdit(sourceId, event) }
  }
  Views.CalendarEventComposer {
    id: composer
    anchors.fill: parent
    visible: editing
    controller: fixture
    textColor: palette.text
    backgroundColor: palette.base
    accentColor: palette.highlight
    urgentColor: palette.highlight
    dimColor: palette.mid
    panelFontFamily: "sans-serif"
  }
  TestCase {
    name: "CalendarGuests"
    when: windowShown

    function resource() {
      return {id:"e1",iCalUID:"e1",etag:"v1",summary:"Planning",
        start:{date:"2026-10-25"},end:{date:"2026-10-26"},
        organizer:{email:"me@example.test",self:true},
        attendees:[{email:"me@example.test",self:true,responseStatus:"accepted"},
          {email:"one@example.test",displayName:"One",responseStatus:"accepted",optional:true},
          {email:"two@example.test",responseStatus:"declined"}]}
    }
    function event() { return Calendar.eventsFromGoogle({items:[resource()]}, fixture.source.id)[0] }

    function textShowing(item, text) {
      if (!item) return null
      if (item.visible && item.text !== undefined && String(item.text) === text) return item
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) { var hit = textShowing(kids[i], text); if (hit) return hit }
      if (item.contentItem) return textShowing(item.contentItem, text)
      return null
    }

    function init() {
      composer.close()
      view.closeDetail()
      serviceFixture.backendCanGoogleCalendars = false
      fixture.pending = []
      fixture.updates = []
      fixture.events = [event()]
      view.visibleWeek = new Date(2026, 9, 25)
      fixture.nowMs = Date.UTC(2026, 9, 25, 12)
      view.setView("week")
      wait(50)
    }

    function openFromTheWeek() {
      var block = findChild(view, "calendar-all-day-event-e1")
      verify(block, "the week view draws the event")
      mouseClick(block, block.width / 2, block.height / 2)
      compare(view.detailOpen, true)
    }

    function editFromTheDetail() {
      var edit = textShowing(view, "Edit...")
      verify(edit, "the detail offers Edit...")
      // Straight after the click that opened the detail, this one would be its
      // double-click.
      wait(Qt.styleHints.mouseDoubleClickInterval + 50)
      mouseClick(edit)
      tryCompare(composer, "editing", true)
    }

    function test_the_detail_lists_every_guest() {
      openFromTheWeek()
      compare(Calendar.attendeeRows(view.detailEvent).length, 3)
      verify(textShowing(view, "Guests · 3"), "the detail heads its guest list with the count")
    }

    function test_an_event_picked_from_the_agenda_lists_every_guest() {
      view.setView("agenda")
      wait(50)
      var row = textShowing(view, "Planning")
      verify(row, "the agenda lists the event")
      mouseClick(row)
      compare(view.detailOpen, true)
      verify(textShowing(view, "Guests · 3"), "the detail heads its guest list with the count")
    }

    function test_an_event_handed_over_directly_lists_every_guest() {
      view.activateEvent(event())
      compare(Calendar.attendeeRows(view.detailEvent).length, 3)
    }

    function editAGoogleEvent() {
      serviceFixture.backendCanGoogleCalendars = true
      openFromTheWeek()
      compare(fixture.pending.length, 1)
      compare(fixture.pending[0].operation, "get")
      fixture.pending[0].callback({body: JSON.stringify(resource())}, "")
      compare(view.detailLoading, false)
      editFromTheDetail()
    }

    function test_removing_every_guest_still_offers_to_save_without_email() {
      editAGoogleEvent()
      var guests = findChild(composer, "event-guests-field")
      verify(guests)
      guests.text = ""
      compare(composer.guestUpdate, true, "the guests being removed are told unless the organizer says otherwise")
    }

    function test_editing_the_guests_keeps_what_google_knows_about_them() {
      editAGoogleEvent()
      var guests = findChild(composer, "event-guests-field")
      verify(guests)
      guests.text = "me@example.test, one@example.test"
      composer.submit("all")
      compare(fixture.updates.length, 1)
      var options = fixture.updates[0].options
      verify(options.ok, options.error)
      compare(options.body.attendees.length, 2)
      compare(options.body.attendees[1].email, "one@example.test")
      compare(options.body.attendees[1].responseStatus, "accepted")
      compare(options.body.attendees[1].displayName, "One")
      compare(options.body.attendees[1].optional, true)
    }
  }
}
