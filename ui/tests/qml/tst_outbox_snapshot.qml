import QtQuick 2.15
import QtTest 1.3
import "../../account" as Account

// The backend pushes outbox snapshots through the bridge's `var` notification
// signal, which on Qt 6.12 turns `entries` into a sequence.
Item {
  id: testRoot
  QtObject {
    id: backend
    property bool ready: true
    property var calls: []
    signal notification(string method, var params)
    function call(method, params, callback) {
      if (method === "outbox.snapshot" && !params.sendId) { callback({accountId: "me@example.org", revision: 0, entries: []}, null); return }
      calls = calls.concat([{method: method, params: params, callback: callback}])
    }
  }
  QtObject { id: auth; signal loggedOut() }
  QtObject {
    id: account
    property var backend: testRoot.parentBackend
    property var auth: testRoot.parentAuth
    property string accountId: "me@example.org"
    property string providerId: "gmail"
    property int undoSendSeconds: 10
    property bool sending: false
    property int sendSecondsRemaining: 0
    property var successes: []
    property var failures: []
    function reportSendSuccess(result, id) { successes = successes.concat([id]) }
    function reportSendFailure(message, id) { failures = failures.concat([id]) }
    function sentDraftRemoved(id) {}
    function note(message) {}
    function deliver(payload) { throw new Error("UI must never deliver mail") }
  }
  property var parentBackend: backend
  property var parentAuth: auth
  Account.SendQueue { id: queue; account: account }
  TestCase {
    name: "OutboxSnapshot"
    function init() {
      queue.parked = []; queue.submitted = ({}); queue.handled = ({}); queue.revision = -1
      queue.deliveryStates = ({}); queue.serverEntries = []; backend.calls = []
      account.successes = []; account.failures = []; account.sending = false
    }
    function snapshot(revision, entries) { return {accountId: account.accountId, revision: revision, entries: entries} }
    function entry(id, state) { return {id: id, state: state, order: 1, queuedAt: Date.now(), dueAt: Date.now() + 10000} }

    function test_a_pushed_snapshot_keeps_its_entries() {
      backend.notification("outbox.changed", snapshot(1, [entry("send1", "queued")]))
      compare(queue.revision, 1)
      compare(queue.serverEntries.length, 1)
      compare(queue.parked.length, 1)
      compare(queue.deliveryStates["send1"], "queued")
    }

    function test_a_pushed_sent_entry_reports_the_receipt() {
      backend.notification("outbox.changed", snapshot(2, [entry("send1", "sent")]))
      compare(account.successes, ["send1"])
      tryVerify(function() {
        return backend.calls.some(function(call) { return call.method === "outbox.forget" && call.params.sendId === "send1" })
      }, 1000, "the receipt is forgotten once reported")
    }

    function test_a_snapshot_handed_over_directly_keeps_its_entries() {
      queue.apply(snapshot(1, [entry("send1", "queued")]))
      compare(queue.serverEntries.length, 1)
    }
  }
}
