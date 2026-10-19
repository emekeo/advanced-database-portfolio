db = db.getSiblingDB("ojougboh_clinical");

const admission = { hospital_no: "OGH/2026/0005", encounter_type: "admission" };

print("=== Replica set members at " + new Date().toISOString());
printjson(
  rs.status().members.map(member => ({
    node: member.name,
    state: member.stateStr,
    health: member.health
  }))
);

print();
print("=== What each member holds for inpatient OGH/2026/0005");
rs.status().members.forEach(member => {
  try {
    const node = new Mongo("mongodb://" + member.name + "/?directConnection=true&serverSelectionTimeoutMS=2000");
    node.setReadPref("secondaryPreferred");
    const record = node.getDB("ojougboh_clinical").clinical_record.findOne(admission, { vitals: 1 });
    printjson({
      node: member.name,
      readings_on_this_node: record.vitals.length,
      latest_reading_at: record.vitals[record.vitals.length - 1].taken_at
    });
  } catch (error) {
    printjson({ node: member.name, error: "not reachable" });
  }
});
