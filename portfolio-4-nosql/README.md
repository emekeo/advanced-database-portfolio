# Portfolio 4 – NoSQL and Advanced Data Models

Portfolios 1 to 3 keep the hospital's structured data in PostgreSQL. This portfolio moves the clinical record, meaning vitals, doctors' notes and patient background, into a **document database** (MongoDB). This is the split decided in Portfolio 1. It is not a copy of the relational database: each part of the data goes where it fits best.

## 1. What goes where

| PostgreSQL (Portfolios 1–3) | MongoDB (this portfolio) |
|---|---|
| Patients, staff, appointments, admissions, beds | Vitals taken at each visit or on the ward |
| Diagnoses with ICD-10 codes, allergies, chronic conditions | Doctors' notes: complaint, examination, plan, ward progress notes |
| Prescriptions, stock, invoices, payments | Family history, social history, childhood and obstetric history |
| **Fixed structure; must never conflict.** Needs foreign keys, check and exclusion constraints, and transactions | **Shape varies from patient to patient. Mostly readings and text, written and read a visit at a time** |

Diagnoses, allergies and chronic conditions stay relational although they are clinical. A drug allergy must point to a real medicine so that clashing prescriptions can be caught, and diagnoses feed NHIS claims and reports through the `disease` table. Those need the guarantees of PostgreSQL.

The two databases are linked by `hospital_no`, and staff by `staff_no` (for example `OGH-0001`). These are the natural keys from Portfolio 1, rather than the internal `patient_id`, so the link survives a reload of either database.

## 2. The document model

### `clinical_record`: one document per visit or admission

```json
{
  "hospital_no": "OGH/2026/0007",
  "encounter_type": "outpatient",
  "recorded_at": "2026-10-01T10:00:00+01:00",
  "doctor": "OGH-0005",
  "vitals": [
    { "taken_at": "2026-10-01T09:45:00+01:00", "taken_by": "OGH-0007",
      "temperature_c": 38.6, "pulse_bpm": 102, "bp": { "systolic": 120, "diastolic": 80 } }
  ],
  "notes": {
    "complaint": "Fever and abdominal pain for 5 days, loss of appetite.",
    "examination": "Febrile, mild tenderness in the right lower abdomen. No guarding.",
    "plan": "Widal and full blood count. Treat as typhoid fever with oral ciprofloxacin."
  }
}
```

The 11 documents cover every completed visit and admission in the Portfolio 1 seed. Their shape differs with the patient:

| Patient | What the document holds that others do not |
|---|---|
| Adult with hypertension (`OGH/2026/0001`) | Blood pressure and weight only |
| Child with malaria (`OGH/2026/0003`) | Respiratory rate, the informant (mother), then an admission with four readings and progress notes |
| Pregnant woman (`OGH/2026/0004`) | Fundal height, foetal heart rate, a `pregnancy` section; the labour admission adds cervical dilation and a `delivery` section with the baby's weight and Apgar scores |
| Diabetic with pneumonia (`OGH/2026/0005`) | Oxygen saturation, oxygen flow, blood glucose at every reading |
| Sickle cell crisis (`OGH/2026/0006`) | Pain score |

**Embedded:** the vitals and the progress notes sit inside the visit as arrays, because they belong to that visit only, are always read with it, and are bounded (a few readings a day for the length of a stay).

### `patient_background`: one document per patient

Family history, social history, and either childhood history (children) or obstetric history (women who have given birth). It is kept apart from the visits because it changes rarely and would otherwise be repeated in every visit. One patient has no family history recorded at all, and one has an empty list: both are valid.

### Validation

MongoDB does not force a schema, but both collections have a `$jsonSchema` validator for the few fields every document must have: `hospital_no` in the hospital's format, `encounter_type` from a fixed list, `recorded_at` as a date, and the doctor. Everything else is free, so a new kind of reading needs no change to the database.

### Indexes

| Index | Used by |
|---|---|
| `{ hospital_no: 1, recorded_at: -1 }` | A patient's record, newest first: the most common read. Same idea as the composite index in Portfolio 2 |
| Text index on the note sections | Searching notes for a word |
| `{ hospital_no: 1 }` unique on `patient_background` | One background document per patient |

## 3. Implementation evidence

`1_load.js` creates the collections, validators and indexes, loads the documents, and prints one outpatient and one admission document to show the difference in shape (`evidence/1_load_output.txt`).

`2_queries.js` runs the queries (`evidence/2_queries_output.txt`):

| # | Query | Shows |
|---|---|---|
| Q1 | A patient's whole record, newest first | One read returns visit, vitals and notes together, with no joins |
| Q2 | Latest vitals reading for an inpatient | `$unwind` and `$sort` over an embedded array |
| Q3 | Visits with any temperature of 38 °C or more | A query reaches inside arrays without extra syntax |
| Q4 | Highest temperature and lowest oxygen saturation per patient | Aggregation over readings with different fields; missing fields are ignored, not errors |
| Q5 | Notes mentioning "malaria" | Text index |
| Q6 | Patients with a family history of hypertension or diabetes | Query on an array of sub-documents |
| Q7 | Plan for Q1 | The compound index is used (`IXSCAN`), as in Portfolio 2 |
| Q8 | Add a reading type no other document has | Accepted with no schema change |
| Q9 | Add a document with no hospital number | Rejected by the validator |
| Q10 | Add a document for a patient who does not exist | **Accepted**: no foreign keys across collections or databases |

Q8 to Q10 add demo documents and the script removes them at the end.

What the recorded run returned:

- The load created 11 `clinical_record` and 10 `patient_background` documents.
- Q1 returned both of `OGH/2026/0005`'s documents (the outpatient visit and the admission) with their notes.
- Q2 returned the reading of 12 October: 36.8 °C, oxygen saturation 97%, blood glucose 7.2.
- Q3 found six visits with a fever, including both readings for the child with malaria and the diabetic with pneumonia.
- Q4 put the child first at 39.8 °C. Patients with no temperature or oxygen reading show `null` rather than causing an error.
- Q5 found the two outpatient visits whose notes mention malaria.
- Q6 found three patients: `OGH/2026/0001`, `0005` and `0008`.
- Q7 used `IXSCAN` on `hospital_no_1_recorded_at_-1` and examined only the 2 matching documents.
- Q8 was accepted, Q9 was rejected with "Document failed validation", and Q10 was accepted.

## 4. Why a document model suits this data

- **The shape varies.** A child, a pregnant woman and a diabetic inpatient have different measurements. In PostgreSQL this needs either one wide table with mostly empty columns, or an entity–attribute–value table (`reading_type`, `value`) that loses data types and needs a join or pivot for every read. A document simply holds the fields that were measured.
- **New measurements appear.** A new clinic or a new protocol (for example head circumference at baby checks) adds fields without a migration, shown by Q8.
- **It is read a visit at a time.** The doctor opens a patient's visit and wants the readings and the notes together. One document per visit returns it in one read (Q1); the relational design would join several tables.
- **Text is first-class.** Notes are free text in sections that differ between doctors and between outpatient and ward care. A text index searches them directly (Q5).
- **It grows separately.** Vitals and notes are the fastest-growing data in a hospital. In a separate database they can grow and scale out (Portfolio 5) without affecting billing and stock.

### What is given up

- **No referential integrity.** Q10 shows a record for a patient who does not exist being accepted. The application has to check `hospital_no` against PostgreSQL before writing.
- **No joins with the relational data.** A report combining fever readings with diagnoses or invoices has to read both databases and combine the results in the application.
- **Weaker consistency rules.** The validator checks only the fields named in it. Nothing stops `temperature_c` being stored in Fahrenheit by mistake. This is acceptable for readings and notes, but it is why money and stock stay in PostgreSQL.
- **Multi-document transactions** exist in MongoDB but are not needed here, since each visit is written as one document. Changes to a single document are atomic.

### Other NoSQL models considered

| Model | Fit for this data |
|---|---|
| Key-value (e.g. Redis) | Good for session data or a cache of today's clinic list. Cannot query inside the value, so no "all visits with fever" |
| Column-family (e.g. Cassandra) | Built for very high write volumes such as monitoring devices sending readings every second. Far more than one hospital's manual vitals |
| Graph (e.g. Neo4j) | Good for tracing relationships, such as contact tracing in an outbreak or referral networks. Visits and notes are not mainly about relationships |

## How to run

MongoDB Community Server and `mongosh` must be installed and running on `localhost:27017`. Run from the repository root, in Git Bash:

```bash
mongosh --quiet --file portfolio-4-nosql/1_load.js > portfolio-4-nosql/evidence/1_load_output.txt 2>&1
```

```bash
mongosh --quiet --file portfolio-4-nosql/2_queries.js > portfolio-4-nosql/evidence/2_queries_output.txt 2>&1
```

In Windows PowerShell, replace `> file 2>&1` with `| Out-File -Encoding utf8 file`, since `>` there writes UTF-16.

`1_load.js` drops and recreates the collections, so it can be run again at any time. `mongosh` prints dates in UTC, so a visit at 09:00 Agbor time (+01:00) appears as 08:00Z.

## Files

| File | Purpose |
|------|---------|
| `1_load.js` | Creates the collections, validators and indexes, and loads the documents |
| `2_queries.js` | Queries, index plan, and the validation and integrity tests |
| `evidence/` | Output of both scripts |
