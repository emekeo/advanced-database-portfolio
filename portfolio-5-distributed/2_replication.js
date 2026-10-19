db = db.getSiblingDB("ojougboh_clinical");

const admission = { hospital_no: "OGH/2026/0005", encounter_type: "admission" };

function readEachNode(newReadingAt) {
  rs.status().members.forEach(member => {
    try {
      const node = new Mongo("mongodb://" + member.name + "/?directConnection=true&serverSelectionTimeoutMS=2000");
      node.setReadPref("secondaryPreferred");
      const record = node.getDB("ojougboh_clinical").clinical_record.findOne(admission, { vitals: 1 });
      const latest = record.vitals[record.vitals.length - 1];
      printjson({
        node: member.name,
        state: member.stateStr,
        readings_on_this_node: record.vitals.length,
        latest_reading_at: latest.taken_at,
        has_the_new_reading: latest.taken_at.getTime() === newReadingAt.getTime()
      });
    } catch (error) {
      printjson({ node: member.name, state: member.stateStr, error: "not reachable" });
    }
  });
}

const primary = rs.status().members.find(member => member.stateStr === "PRIMARY").name;

print("=== A nurse records a new vitals reading for inpatient OGH/2026/0005");
print("The application writes to the primary, " + primary + ", and waits for a majority of members to confirm");
const takenAt = new Date();
const result = db.clinical_record.updateOne(
  admission,
  { $push: { vitals: { taken_at: takenAt, taken_by: "OGH-0006", temperature_c: 36.7, pulse_bpm: 78, resp_rate: 18, spo2_pct: 98, blood_glucose_mmol_l: 6.9 } } },
  { writeConcern: { w: "majority" } }
);
printjson({ written_at: takenAt, modified: result.modifiedCount, acknowledged: result.acknowledged });

print();
print("=== One second later, read the admission back from every member directly");
sleep(1000);
readEachNode(takenAt);
