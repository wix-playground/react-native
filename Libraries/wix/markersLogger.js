import React from 'react';
import {View, DeviceEventEmitter} from 'react-native';

const performanceNow = require("fbjs/lib/performanceNow");

// Construct a simple trace record
const traceRecord = ({
                       name,
                       time: ts,
                       tag = null,
                       instanceKey = 0,
                       tid = 0,
                       pid = 0
                     }) => ({
  cat: "react-native",
  ph: "I",
  name,
  ts,
  pid,
  tid,
  args: {
    instanceKey,
    tag
  }
});

// Gets the logs that Java sends from ReactMarker and converts them into the format that
// chrome://tracing can understand.
// Note that we should not really do this on the device, but send the data to the server
// and the server to change the format
const logsToTrace = (logs, epochStart) => {
  const findClosingEventTime = (
    { name, args: { tag, instanceKey } },
    index,
    records
  ) => {
    const endEvents = records.filter(
      e =>
        e.name.endsWith("_END") &&
        e.name.replace(/_END$/, "_START") === name &&
        // Either the tag, or the instance, or both will match for the end tag
        (e.tag ? e.tag === tag : e.instanceKey === instanceKey)
    );

    if (endEvents.length) {
      return endEvents[0].time;
    }

    if (__DEV__) {
      console.log(
        "Could not find the ending event for ",
        name,
        tag,
        instanceKey
      );
    }
  };

  const traceEvents = [];
  // Iterate over each element find its closing event, and add that to the list of traceEvents
  logs.forEach((record, index) => {
    let event = traceRecord({ ...record, time: (record.time - epochStart) * 1000 });
    if (record.name.endsWith("_START")) {
      const endTime = findClosingEventTime(event, index, logs);
      if (typeof endTime !== "undefined") {
        event.ph = "X";
        event.dur = (endTime - record.time) * 1000;
      }
      event.name = record.name.replace(/_START$/, "");

      traceEvents.push(event);
    } else if (event.name.endsWith("_END")) {
      // Nothing to do for end event, we have already processed it
    } else {
      // This is an instant event - an event without a close. We just log this
      traceEvents.push(event);
    }
  });
  return traceEvents;
};

let jsStartTime = performanceNow();

// Function to convert raw logs to a format that chrome://tracing can consume.
// Ideally this should be done at the server, not on the device
const getTrace = (jsVarName) => {
  const trace = { traceEvents: [] };
  const loggerRecords = global[jsVarName];
  if (typeof loggerRecords !== "undefined") {
    if (typeof loggerRecords.startTime !== "undefined") {
      jsStartTime = loggerRecords.startTime;
    }

    if (typeof loggerRecords.data !== "undefined") {
      trace.traceEvents = logsToTrace(loggerRecords.data, jsStartTime);
    }
  }

  // Iterate over the JS components logs, and convert them.
  for (var name in jsTimeSpans) {
    let { start, end } = jsTimeSpans[name];
    const event = traceRecord({
      name,
      time: (start - jsStartTime) * 1000,
      tag: "JS_EVENT"
    });
    event.ph = "X";
    event.dur = end - start;
    trace.traceEvents.push(event);
  }
  return trace;
};

// A helper to record timespans that JS components send us
const jsTimeSpans = {};
const TimeSpan = {
  start(name) {
    jsTimeSpans[name] = { start: performanceNow() };
  },
  stop(name) {
    const timespan = jsTimeSpans[name];
    if (typeof timespan !== "undefined") {
      jsTimeSpans[name] = { ...timespan, end: performanceNow() };
    }
  }
};

// A simple component to record the time taken to construct and mount JS components
class ComponentLogger extends React.Component {
  _hasLoggedUpdate = false;
  constructor(props) {
    super(props);
    const { name, type } = this.props;
    TimeSpan[type](name + "_mount");
  }

  shouldComponentUpdate() {
    if (!this._hasLoggedUpdate) {
      const { name, type } = this.props;
      this._hasLoggedUpdate = true;
      TimeSpan[type](name + "_update");
    }
    return false;
  }

  render() {
    return null;
  }
}

module.exports = {
  // Use this function in your JS code to instrument load time. Usage is
  // render() { logComponentPerf('Component_NAME', <Component ...props />); }
  logComponentPerf(name, component) {
    return (
      <View style={{flex: 1}}>
        <ComponentLogger type="start" name={name} />
        {component}
        <ComponentLogger type="stop" name={name} />
      </View>
    );
  },
};

DeviceEventEmitter.addListener('MarkersLog.ready', async (jsVarName) => {
  console.log('RNMARKERS_LOGGER', 'Fetching logs from native side...');
  const RNFS = require('react-native-fs');
  const outputFile = RNFS.ExternalDirectoryPath + '/trace.json';
  await RNFS.writeFile(outputFile, JSON.stringify(getTrace(jsVarName)));
  console.log('RNMARKERS_LOGGER', `Done! run 'adb pull ${outputFile}' to get it`);
});
