db = db.getSiblingDB("ojougboh_clinical");

print("=== Q1: Full clinical record for inpatient OGH/2026/0005, newest first (one read, no joins)");
printjson(
  db.clinical_record
    .find({ hospital_no: "OGH/2026/0005" }, { _id: 0, encounter_type: 1, recorded_at: 1, ward: 1, "notes.plan": 1, "notes.progress.text": 1 })
    .sort({ recorded_at: -1 })
    .toArray()
);

print();
print("=== Q2: Latest vitals reading for OGH/2026/0005");
printjson(
  db.clinical_record.aggregate([
    { $match: { hospital_no: "OGH/2026/0005" } },
    { $unwind: "$vitals" },
    { $sort: { "vitals.taken_at": -1 } },
    { $limit: 1 },
    { $project: { _id: 0, hospital_no: 1, vitals: 1 } }
  ]).toArray()
);

print();
print("=== Q3: Visits with any temperature reading of 38.0 C or more (searches inside the vitals arrays)");
printjson(
  db.clinical_record
    .find({ "vitals.temperature_c": { $gte: 38.0 } }, { _id: 0, hospital_no: 1, encounter_type: 1, recorded_at: 1 })
    .sort({ recorded_at: 1 })
    .toArray()
);

print();
print("=== Q4: Highest temperature and lowest oxygen saturation per patient");
printjson(
  db.clinical_record.aggregate([
    { $unwind: "$vitals" },
    { $group: {
        _id: "$hospital_no",
        readings: { $sum: 1 },
        highest_temperature_c: { $max: "$vitals.temperature_c" },
        lowest_spo2_pct: { $min: "$vitals.spo2_pct" }
    } },
    { $sort: { highest_temperature_c: -1 } }
  ]).toArray()
);

print();
print("=== Q5: Notes that mention malaria (text index over the note sections)");
printjson(
  db.clinical_record
    .find({ $text: { $search: "malaria" } }, { _id: 0, hospital_no: 1, encounter_type: 1, recorded_at: 1 })
    .sort({ recorded_at: 1 })
    .toArray()
);

print();
print("=== Q6: Patients with a parent or sibling with hypertension or diabetes");
printjson(
  db.patient_background
    .find(
      { "family_history.condition": { $in: ["Hypertension", "Type 2 diabetes mellitus"] } },
      { _id: 0, hospital_no: 1, family_history: 1 }
    )
    .sort({ hospital_no: 1 })
    .toArray()
);

print();
print("=== Q7: Index use for Q1 (winning plan)");
const explained = db.clinical_record
  .find({ hospital_no: "OGH/2026/0005" })
  .sort({ recorded_at: -1 })
  .explain("executionStats");
const stages = [];
let plan = explained.queryPlanner.winningPlan.queryPlan ?? explained.queryPlanner.winningPlan;
while (plan) {
  stages.push(plan.indexName ? plan.stage + " (" + plan.indexName + ")" : plan.stage);
  plan = plan.inputStage;
}
printjson({
  stages: stages,
  documents_examined: explained.executionStats.totalDocsExamined,
  documents_returned: explained.executionStats.nReturned
});

print();
print("=== Q8: A new kind of reading needs no schema change (head circumference for a baby)");
const added = db.clinical_record.insertOne({
  hospital_no: "OGH/2026/0004",
  encounter_type: "outpatient",
  recorded_at: ISODate("2026-10-11T09:00:00+01:00"),
  doctor: "OGH-0002",
  vitals: [{ taken_at: ISODate("2026-10-11T08:50:00+01:00"), taken_by: "OGH-0008", baby_weight_kg: 3.5, head_circumference_cm: 35 }],
  notes: { plan: "Baby check at one week. Feeding well." },
  demo: true
});
printjson({ inserted: added.acknowledged });

print();
print("=== Q9: The validator still rejects a document without the required fields");
try {
  db.clinical_record.insertOne({ encounter_type: "outpatient", recorded_at: new Date(), notes: { plan: "No hospital number" } });
} catch (error) {
  print("Rejected: " + error.message);
}

print();
print("=== Q10: But nothing checks that the patient exists, as a PostgreSQL foreign key would");
const orphan = db.clinical_record.insertOne({
  hospital_no: "OGH/2026/9999",
  encounter_type: "outpatient",
  recorded_at: ISODate("2026-10-11T10:00:00+01:00"),
  doctor: "OGH-0001",
  notes: { plan: "Patient OGH/2026/9999 does not exist in PostgreSQL" },
  demo: true
});
printjson({ inserted: orphan.acknowledged });

print();
print("--- Remove the demo documents");
printjson({ deleted: db.clinical_record.deleteMany({ demo: true }).deletedCount });
