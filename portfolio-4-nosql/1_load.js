db = db.getSiblingDB("ojougboh_clinical");

db.clinical_record.drop();
db.patient_background.drop();

db.createCollection("clinical_record", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["hospital_no", "encounter_type", "recorded_at", "doctor"],
      properties: {
        hospital_no: { bsonType: "string", pattern: "^OGH/[0-9]{4}/[0-9]{4,5}$" },
        encounter_type: { enum: ["outpatient", "antenatal", "admission"] },
        recorded_at: { bsonType: "date" },
        doctor: { bsonType: "string" },
        vitals: { bsonType: "array", items: { bsonType: "object", required: ["taken_at"] } },
        notes: { bsonType: "object" }
      }
    }
  }
});

db.createCollection("patient_background", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["hospital_no"],
      properties: {
        hospital_no: { bsonType: "string", pattern: "^OGH/[0-9]{4}/[0-9]{4,5}$" },
        family_history: { bsonType: "array" },
        social_history: { bsonType: "object" }
      }
    }
  }
});

print("=== Collections created with a validator on the fields every document must have");
printjson(db.getCollectionNames());

db.clinical_record.insertMany([
  {
    hospital_no: "OGH/2026/0001",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-01T09:00:00+01:00"),
    doctor: "OGH-0001",
    vitals: [
      { taken_at: ISODate("2026-10-01T08:50:00+01:00"), taken_by: "OGH-0006",
        bp: { systolic: 150, diastolic: 95 }, pulse_bpm: 78, weight_kg: 84 }
    ],
    notes: {
      complaint: "Routine blood pressure review. No headache or chest pain.",
      examination: "Well. Heart sounds normal. No ankle swelling.",
      plan: "BP still above target. Continue amlodipine 10mg daily, reduce salt, review in one week."
    }
  },
  {
    hospital_no: "OGH/2026/0007",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-01T10:00:00+01:00"),
    doctor: "OGH-0005",
    vitals: [
      { taken_at: ISODate("2026-10-01T09:45:00+01:00"), taken_by: "OGH-0007",
        temperature_c: 38.6, pulse_bpm: 102, bp: { systolic: 120, diastolic: 80 } }
    ],
    notes: {
      complaint: "Fever and abdominal pain for 5 days, loss of appetite.",
      examination: "Febrile, mild tenderness in the right lower abdomen. No guarding.",
      plan: "Widal and full blood count. Treat as typhoid fever with oral ciprofloxacin. Return if pain worsens."
    }
  },
  {
    hospital_no: "OGH/2026/0003",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-02T09:00:00+01:00"),
    doctor: "OGH-0002",
    vitals: [
      { taken_at: ISODate("2026-10-02T08:40:00+01:00"), taken_by: "OGH-0008",
        temperature_c: 39.8, pulse_bpm: 140, resp_rate: 36, weight_kg: 21.5 }
    ],
    notes: {
      complaint: "High fever and vomiting since yesterday, brought in by mother.",
      examination: "Hot, lethargic, mildly dehydrated. Not able to keep oral drugs down.",
      plan: "Malaria parasite test strongly positive. Admit to Children's Ward for IV artesunate.",
      informant: "Mother, Joy Udoh"
    }
  },
  {
    hospital_no: "OGH/2026/0003",
    encounter_type: "admission",
    recorded_at: ISODate("2026-10-02T10:00:00+01:00"),
    doctor: "OGH-0002",
    ward: "Children's Ward",
    vitals: [
      { taken_at: ISODate("2026-10-02T10:00:00+01:00"), taken_by: "OGH-0008", temperature_c: 39.4, pulse_bpm: 136, resp_rate: 34 },
      { taken_at: ISODate("2026-10-02T22:00:00+01:00"), taken_by: "OGH-0007", temperature_c: 38.7, pulse_bpm: 124, resp_rate: 30 },
      { taken_at: ISODate("2026-10-03T10:00:00+01:00"), taken_by: "OGH-0008", temperature_c: 38.1, pulse_bpm: 112, resp_rate: 28 },
      { taken_at: ISODate("2026-10-04T10:00:00+01:00"), taken_by: "OGH-0008", temperature_c: 37.2, pulse_bpm: 98, resp_rate: 24, weight_kg: 21.8 }
    ],
    notes: {
      progress: [
        { at: ISODate("2026-10-03T09:00:00+01:00"), by: "OGH-0002", text: "Three doses of IV artesunate given. Fever settling, drinking well." },
        { at: ISODate("2026-10-05T11:00:00+01:00"), by: "OGH-0002", text: "Afebrile for 24 hours, eating. Discharge on oral paracetamol syrup." }
      ]
    }
  },
  {
    hospital_no: "OGH/2026/0002",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-02T11:00:00+01:00"),
    doctor: "OGH-0005",
    vitals: [
      { taken_at: ISODate("2026-10-02T10:45:00+01:00"), taken_by: "OGH-0007",
        temperature_c: 38.2, pulse_bpm: 96, bp: { systolic: 110, diastolic: 70 } }
    ],
    notes: {
      complaint: "Headache and fever for 2 days.",
      examination: "Febrile, alert, no neck stiffness.",
      plan: "Malaria parasite test positive. Uncomplicated malaria, treat with artemether/lumefantrine."
    }
  },
  {
    hospital_no: "OGH/2026/0008",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-03T09:00:00+01:00"),
    doctor: "OGH-0001",
    vitals: [
      { taken_at: ISODate("2026-10-03T08:50:00+01:00"), taken_by: "OGH-0006",
        temperature_c: 37.6, pulse_bpm: 88, bp: { systolic: 118, diastolic: 76 } }
    ],
    notes: {
      complaint: "Painful and frequent urination for 3 days.",
      examination: "Mild tenderness above the pubic bone. No loin pain.",
      plan: "Urinalysis shows nitrites. Treat as urinary tract infection with ciprofloxacin, plenty of fluids."
    }
  },
  {
    hospital_no: "OGH/2026/0004",
    encounter_type: "antenatal",
    recorded_at: ISODate("2026-10-03T12:00:00+01:00"),
    doctor: "OGH-0003",
    vitals: [
      { taken_at: ISODate("2026-10-03T11:45:00+01:00"), taken_by: "OGH-0006",
        bp: { systolic: 120, diastolic: 80 }, weight_kg: 78, fundal_height_cm: 38, foetal_heart_bpm: 142 }
    ],
    pregnancy: { gestation_weeks: 39, gravida: 2, para: 1, presentation: "cephalic", expected_delivery: ISODate("2026-10-10T00:00:00+01:00") },
    notes: {
      examination: "Well. Baby head down, moving well. No swelling, no protein in urine.",
      plan: "Come in at once if labour starts or waters break."
    }
  },
  {
    hospital_no: "OGH/2026/0004",
    encounter_type: "admission",
    recorded_at: ISODate("2026-10-04T02:00:00+01:00"),
    doctor: "OGH-0003",
    ward: "Maternity Ward",
    vitals: [
      { taken_at: ISODate("2026-10-04T02:00:00+01:00"), taken_by: "OGH-0006", bp: { systolic: 124, diastolic: 82 }, pulse_bpm: 90, foetal_heart_bpm: 140, cervical_dilation_cm: 5 },
      { taken_at: ISODate("2026-10-04T06:00:00+01:00"), taken_by: "OGH-0006", bp: { systolic: 126, diastolic: 84 }, pulse_bpm: 94, foetal_heart_bpm: 138, cervical_dilation_cm: 9 },
      { taken_at: ISODate("2026-10-04T09:00:00+01:00"), taken_by: "OGH-0006", bp: { systolic: 118, diastolic: 76 }, pulse_bpm: 86, temperature_c: 36.9 }
    ],
    delivery: {
      at: ISODate("2026-10-04T07:20:00+01:00"),
      mode: "spontaneous vaginal",
      baby: { sex: "M", weight_kg: 3.4, apgar: [8, 9] },
      blood_loss_ml: 250
    },
    notes: {
      progress: [
        { at: ISODate("2026-10-04T07:30:00+01:00"), by: "OGH-0003", text: "Normal delivery of a baby boy. Mother and baby well." },
        { at: ISODate("2026-10-06T10:30:00+01:00"), by: "OGH-0003", text: "Breastfeeding well. Discharge, postnatal clinic in 6 weeks." }
      ]
    }
  },
  {
    hospital_no: "OGH/2026/0005",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-05T10:00:00+01:00"),
    doctor: "OGH-0001",
    vitals: [
      { taken_at: ISODate("2026-10-05T09:40:00+01:00"), taken_by: "OGH-0006",
        temperature_c: 38.9, pulse_bpm: 110, resp_rate: 28, spo2_pct: 91,
        bp: { systolic: 150, diastolic: 90 }, blood_glucose_mmol_l: 14.2 }
    ],
    notes: {
      complaint: "Cough with yellow sputum and breathlessness for 4 days.",
      examination: "Crackles over the right lower chest. Oxygen saturation low.",
      plan: "Pneumonia in a diabetic. Admit to Male Medical Ward for IV ceftriaxone and oxygen. Check blood sugar four times a day."
    }
  },
  {
    hospital_no: "OGH/2026/0005",
    encounter_type: "admission",
    recorded_at: ISODate("2026-10-05T11:00:00+01:00"),
    doctor: "OGH-0001",
    ward: "Male Medical Ward",
    vitals: [
      { taken_at: ISODate("2026-10-05T12:00:00+01:00"), taken_by: "OGH-0006", temperature_c: 38.7, pulse_bpm: 108, resp_rate: 26, spo2_pct: 93, oxygen_l_min: 2, blood_glucose_mmol_l: 12.8 },
      { taken_at: ISODate("2026-10-06T08:00:00+01:00"), taken_by: "OGH-0007", temperature_c: 38.0, pulse_bpm: 100, resp_rate: 24, spo2_pct: 94, oxygen_l_min: 2, blood_glucose_mmol_l: 10.4 },
      { taken_at: ISODate("2026-10-08T08:00:00+01:00"), taken_by: "OGH-0006", temperature_c: 37.4, pulse_bpm: 88, resp_rate: 20, spo2_pct: 96, blood_glucose_mmol_l: 8.1 },
      { taken_at: ISODate("2026-10-12T08:00:00+01:00"), taken_by: "OGH-0007", temperature_c: 36.8, pulse_bpm: 80, resp_rate: 18, spo2_pct: 97, bp: { systolic: 138, diastolic: 84 }, blood_glucose_mmol_l: 7.2 }
    ],
    notes: {
      progress: [
        { at: ISODate("2026-10-06T09:00:00+01:00"), by: "OGH-0001", text: "Chest X-ray confirms right lower lobe pneumonia. Continue ceftriaxone." },
        { at: ISODate("2026-10-08T09:00:00+01:00"), by: "OGH-0001", text: "Off oxygen. Fever settling, blood sugar improving on metformin." },
        { at: ISODate("2026-10-12T09:00:00+01:00"), by: "OGH-0001", text: "Comfortable, walking on the ward. Plan discharge after the 7-day ceftriaxone course." }
      ]
    }
  },
  {
    hospital_no: "OGH/2026/0006",
    encounter_type: "outpatient",
    recorded_at: ISODate("2026-10-05T11:00:00+01:00"),
    doctor: "OGH-0005",
    vitals: [
      { taken_at: ISODate("2026-10-05T10:50:00+01:00"), taken_by: "OGH-0007",
        temperature_c: 37.4, pulse_bpm: 98, pain_score: 6 }
    ],
    notes: {
      complaint: "Pain in both legs and lower back since this morning.",
      examination: "Not pale, not jaundiced. Tender over both thighs.",
      plan: "Mild sickle cell bone pain crisis. Ibuprofen, plenty of fluids, continue folic acid."
    }
  }
]);

db.patient_background.insertMany([
  {
    hospital_no: "OGH/2026/0001",
    family_history: [
      { relative: "father", condition: "Hypertension" },
      { relative: "father", condition: "Stroke", note: "Died aged 70" }
    ],
    social_history: { occupation: "Retired civil servant", smoking: "former, stopped 2010", alcohol: "occasional palm wine" }
  },
  {
    hospital_no: "OGH/2026/0002",
    family_history: [{ relative: "mother", condition: "Asthma" }],
    social_history: { occupation: "Teacher", smoking: "never", alcohol: "none" }
  },
  {
    hospital_no: "OGH/2026/0003",
    family_history: [],
    childhood: { birth: "term, normal delivery", immunisations_up_to_date: true, school: "Primary 1" }
  },
  {
    hospital_no: "OGH/2026/0004",
    family_history: [{ relative: "mother", condition: "Twin pregnancies" }],
    social_history: { occupation: "Hairdresser", smoking: "never", alcohol: "none" },
    obstetric_history: [
      { year: 2023, outcome: "live birth", mode: "spontaneous vaginal", baby_weight_kg: 3.1 }
    ]
  },
  {
    hospital_no: "OGH/2026/0005",
    family_history: [
      { relative: "mother", condition: "Type 2 diabetes mellitus" },
      { relative: "brother", condition: "Type 2 diabetes mellitus" },
      { relative: "father", condition: "Hypertension" }
    ],
    social_history: { occupation: "Trader", smoking: "never", alcohol: "2 bottles of beer a week", lives_with: "wife" }
  },
  {
    hospital_no: "OGH/2026/0006",
    family_history: [
      { relative: "mother", condition: "Sickle cell trait", note: "Genotype AS" },
      { relative: "father", condition: "Sickle cell trait", note: "Genotype AS" }
    ],
    social_history: { occupation: "University student", smoking: "never", alcohol: "none" }
  },
  {
    hospital_no: "OGH/2026/0007",
    social_history: { occupation: "Okada rider", smoking: "10 cigarettes a day", alcohol: "regular", water_source: "borehole" }
  },
  {
    hospital_no: "OGH/2026/0008",
    family_history: [{ relative: "father", condition: "Hypertension" }],
    social_history: { occupation: "Nurse", smoking: "never", alcohol: "none" }
  },
  {
    hospital_no: "OGH/2026/0009",
    family_history: [{ relative: "father", condition: "Asthma" }],
    childhood: { birth: "preterm at 35 weeks", immunisations_up_to_date: true, school: "JSS 2" }
  },
  {
    hospital_no: "OGH/2026/0010",
    family_history: [{ relative: "sister", condition: "Breast cancer", note: "Diagnosed aged 48" }],
    social_history: { occupation: "Caterer", smoking: "never", alcohol: "none" }
  }
]);

db.clinical_record.createIndex({ hospital_no: 1, recorded_at: -1 });
db.clinical_record.createIndex({ "notes.complaint": "text", "notes.examination": "text", "notes.plan": "text", "notes.progress.text": "text" });
db.patient_background.createIndex({ hospital_no: 1 }, { unique: true });

print();
print("=== Documents loaded");
printjson({
  clinical_record: db.clinical_record.countDocuments(),
  patient_background: db.patient_background.countDocuments()
});

print();
print("=== Indexes on clinical_record");
printjson(db.clinical_record.getIndexes().map(index => index.name));

print();
print("=== One outpatient document and one admission document, to show how the shape differs");
printjson(db.clinical_record.findOne({ hospital_no: "OGH/2026/0007" }, { _id: 0 }));
printjson(db.clinical_record.findOne({ hospital_no: "OGH/2026/0004", encounter_type: "admission" }, { _id: 0 }));
