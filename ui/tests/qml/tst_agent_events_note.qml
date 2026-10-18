import QtQuick
import QtTest
import "../../agent" as AI
import "../../agent/Agent.js" as Agent

// A finished look for events reaches Service.qml through the runner's
// `jobFinished(var job)` signal, which on Qt 6.12 turns `events` into a
// sequence.
Item {
  Component {
    id: factory
    AI.AgentRunner { pluginDir: "/synthetic" }
  }
  Component {
    id: backendFactory
    QtObject {
      property bool ready: true
      property int apiVersion: 6
      property var requests: []
      property var projection: ({byMessage:{},anyActive:false,activeIds:[],finishedIds:[],attention:false,attentionByMessage:{},newlyFinished:[]})
      function call(method, params, callback) {
        if (method === "agent.providerStatus") { callback({available:true,provider:params.provider || "claude"}, ""); return }
        if (method === "agent.jobsProjection") { callback(projection, ""); return }
        requests = requests.concat([{method:method,params:params,callback:callback}])
      }
      function finish(index,result,error) {requests[index].callback(result,error || "")}
    }
  }
  TestCase {
    name: "AgentEventsNote"
    property var runner
    property var bridge
    property var notes: []
    function init() {
      runner=createTemporaryObject(factory,parent)
      bridge=createTemporaryObject(backendFactory,parent)
      runner.backend=bridge
      wait(1)
      if(bridge.requests.length)bridge.finish(0,[])
      bridge.requests=[]
      notes=[]
      runner.jobFinished.connect(function(job) { notes = notes.concat([Agent.finishedNote(job)]) })
    }
    function eventsJob(events) { return {id:"j1",kind:"events",state:"done",subject:"Dinner",events:events} }
    function finishWith(job) {
      runner.jobs=[{id:"j1",state:"running"}]
      runner.refresh()
      bridge.projection.newlyFinished=[job]
      bridge.finish(0,[{id:"j1",state:"done"}])
    }

    function test_a_finished_look_names_how_many_events_it_found() {
      finishWith(eventsJob([{title:"a"},{title:"b"}]))
      compare(notes, ["The agent found 2 events in “Dinner”"])
    }

    function test_a_finished_look_names_a_single_event() {
      finishWith(eventsJob([{title:"a"}]))
      compare(notes, ["The agent found an event in “Dinner”"])
    }

    function test_a_look_that_found_nothing_says_nothing() {
      finishWith(eventsJob([]))
      compare(notes, [""])
    }

    function test_a_job_handed_over_directly_counts_its_events() {
      compare(Agent.finishedNote(eventsJob([{title:"a"},{title:"b"}])), "The agent found 2 events in “Dinner”")
    }
  }
}
