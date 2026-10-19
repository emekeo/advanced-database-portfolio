db = db.getSiblingDB("ojougboh_clinical");

const admission = { hospital_no: "OGH/2026/0005", encounter_type: "admission" };

function hasReading(host, takenAt) {
  const node = new Mongo("mongodb://" + host + "/?directConnection=true&serverSelectionTimeoutMS=2000");
  node.setReadPref("secondaryPreferred");
  const record = node.getDB("ojougboh_clinical").clinical_record.findOne(admission, { vitals: 1 });
  return record.vitals.some(reading => reading.taken_at.getTime() === takenAt.getTime());
}

function setDelay(host, seconds) {
  const config = rs.conf();
  const member = config.members.find(configured => configured.host === host);
  member.priority = seconds > 0 ? 0 : 1;
  member.hidden = seconds > 0;
  member.secondaryDelaySecs = seconds;
  rs.reconfig(config);
}

const members = rs.status().members;
const primary = members.find(member => member.stateStr === "PRIMARY").name;
const secondaries = members.filter(member => member.stateStr === "SECONDARY").map(member => member.name);
const upToDate = secondaries[0];
const delayed = secondaries[1];

print("=== Setup: primary " + primary + ", up-to-date secondary " + upToDate + ", delayed secondary " + delayed);
print("The delayed member applies changes 20 seconds late, like a copy at a second site on a slow link");
setDelay(delayed, 20);
sleep(3000);

print();
print("##### PART 1: a write confirmed by the primary alone (w: 1), then read from each copy");
const firstReading = new Date();
db.clinical_record.updateOne(
  admission,
  { $push: { vitals: { taken_at: firstReading, taken_by: "OGH-0007", temperature_c: 36.6, pulse_bpm: 76, spo2_pct: 98 } } },
  { writeConcern: { w: 1 } }
);
sleep(2000);
printjson({
  seconds_after_write: 2,
  primary_has_it: hasReading(primary, firstReading),
  up_to_date_secondary_has_it: hasReading(upToDate, firstReading),
  delayed_secondary_has_it: hasReading(delayed, firstReading)
});
print("A doctor reading from the delayed copy would see the old record: a stale read.");

print();
print("Waiting 25 seconds...");
sleep(25000);
printjson({
  seconds_after_write: 27,
  primary_has_it: hasReading(primary, firstReading),
  up_to_date_secondary_has_it: hasReading(upToDate, firstReading),
  delayed_secondary_has_it: hasReading(delayed, firstReading)
});
print("All three copies now agree: the data is eventually consistent.");

print();
print("##### PART 2: how many members must confirm a write before the application carries on");

const majorityReading = new Date();
let started = Date.now();
db.clinical_record.updateOne(
  admission,
  { $push: { vitals: { taken_at: majorityReading, taken_by: "OGH-0007", temperature_c: 36.8, pulse_bpm: 80, spo2_pct: 97 } } },
  { writeConcern: { w: "majority", wtimeout: 5000 } }
);
printjson({ write_concern: "majority (2 of 3)", result: "confirmed", milliseconds: Date.now() - started });

const allReading = new Date();
started = Date.now();
try {
  db.clinical_record.updateOne(
    admission,
    { $push: { vitals: { taken_at: allReading, taken_by: "OGH-0007", temperature_c: 36.9, pulse_bpm: 79, spo2_pct: 98 } } },
    { writeConcern: { w: 3, wtimeout: 5000 } }
  );
  printjson({ write_concern: "all 3", result: "confirmed", milliseconds: Date.now() - started });
} catch (error) {
  printjson({ write_concern: "all 3", result: "timed out", milliseconds: Date.now() - started, error: error.message });
}
printjson({ reading_is_on_the_primary_anyway: hasReading(primary, allReading) });
print("The write was not undone: the timeout only means the application could not be told that every copy had it.");

print();
print("--- Put the delayed member back to normal");
setDelay(delayed, 0);
sleep(3000);
printjson(
  rs.conf().members.map(member => ({ node: member.host, priority: member.priority, hidden: member.hidden, delay_seconds: member.secondaryDelaySecs }))
);
