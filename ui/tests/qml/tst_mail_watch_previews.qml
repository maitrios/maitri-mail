import QtQuick 2.15
import QtTest 1.3
import "transports.js" as Transports
import "../../account" as Account

// New unread mail reaches the bar previews through two `var` signals, the
// bridge's notification and BackendSync's `updated`, which on Qt 6.12 turn
// the snapshot's `messages` into a sequence.
Item {
  width: 400
  height: 300

  Component {
    id: accountComponent
    Account.MailAccount {
      id: mailbox

      pluginDir: "/tmp/maitri-mail-test"
      accountId: "jmap:ada@example.org"
      configuredEmail: "ada@example.org"
      providerId: "jmap"
      jmapSettings: ({
        sessionUrl: "https://mail.example.org/jmap/session",
        username: "ada@example.org",
        authScheme: "basic",
        accountId: "t"
      })
      active: true
      windowOpen: true
    }

  }

  Component {
    id: backendComponent
    QtObject {
      property bool ready: true
      property bool executable: false
      property var protocolInfo: ({ methods: ["mail.watch", "mail.check", "mail.unwatch", "message.summaries"] })
      property var calls: []
      signal notification(string method, var params)
      function call(method, params, callback) {
        calls = calls.concat([method])
        if (method === "mail.watch") { callback({ accountId: params.accountId, sequence: 0, estimate: 0, messages: [] }, null); return }
        if (method === "message.summaries") {
          var out = []
          for (var i = 0; i < params.messages.length; i++) out.push({ id: params.messages[i].id, subject: "S" + i, date: new Date().toISOString(), from: { display: "x", email: "x@example.org" } })
          callback({ summaries: out }, null); return
        }
      }
    }
  }

  TestCase {
    name: "MailWatchPreviews"
    readonly property var session: ({
      capabilities: {
        "urn:ietf:params:jmap:core": {},
        "urn:ietf:params:jmap:mail": {}
      },
      accounts: {
        t: {
          name: "ada@example.org",
          isPersonal: true,
          isReadOnly: false,
          accountCapabilities: {
            "urn:ietf:params:jmap:mail": { emailQuerySortOptions: ["receivedAt"] }
          }
        }
      },
      primaryAccounts: {
        "urn:ietf:params:jmap:core": "t",
        "urn:ietf:params:jmap:mail": "t"
      },
      apiUrl: "https://api.example.org/jmap/",
      state: "s0"
    })

    readonly property var mailboxes: [
      { id: "a", name: "Inbox", role: "inbox", parentId: null, totalEmails: 1, unreadEmails: 1 },
      { id: "b", name: "Trash", role: "trash", parentId: null, totalEmails: 0, unreadEmails: 0 }
    ]

    property var account: null

    function init() {
      account = createTemporaryObject(accountComponent, parent)
      verify(!!account)
      account.backend = createTemporaryObject(backendComponent, parent)
      Transports.install(account.api)
      account.api.session = session
      account.api.mailboxList = mailboxes
      account.api.mailboxesLoaded = true
      account.auth.secret = "app-password"
      account.auth.secretChecked = true
      tryVerify(function() { return account.ready }, 2000)
      wait(1)
      account.queuedActions = []
      account.pendingAction = ""
      account.previewMessages = []
      account.selectedThread = null
      account.memberSummaries = ({})
      account.messages = [{ id: "m3", subject: "One", unread: true, starred: false,
        labelIds: ["INBOX", "UNREAD"], thread: { id: "d", count: 3,
          unread: true, flagged: false, memberIds: ["m1", "m2", "m3"] } }]
      account.listLoaded = true
      account.listLoading = false
    }

    function test_the_account_watches_through_the_backend() {
      verify(account.nativePolling)
      tryVerify(function() { return account.backend.calls.indexOf("mail.watch") >= 0 }, 1000)
    }

    function test_pushed_new_mail_updates_the_bar_previews() {
      tryVerify(function() { return account.backend.calls.indexOf("mail.watch") >= 0 }, 1000)
      account.backend.notification("mail.updated", { accountId: "jmap:ada@example.org", sequence: 5,
        estimate: 2, fingerprint: "f1", error: "", messages: [{ id: "m1" }, { id: "m2" }] })
      tryCompare(account, "inboxUnread", 2)
      compare(account.previewMessages.length, 2)
      compare(account.previewMessages[0].subject, "S0")
      compare(account.previewMessages[1].unread, true)
    }

    function test_a_list_handed_over_directly_is_summarized() {
      var got = null
      account.summarizeResources([{ id: "m1" }, { id: "m2" }], function(list, error) { got = list })
      tryVerify(function() { return got !== null })
      compare(got.length, 2)
      compare(got[1].nativeSummary.subject, "S1")
    }
  }
}
