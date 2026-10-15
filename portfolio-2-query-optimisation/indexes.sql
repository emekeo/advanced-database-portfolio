SET search_path TO hospital, public;

CREATE INDEX IF NOT EXISTS appointment_patient_starts_at_idx ON appointment (patient_id, starts_at);
CREATE INDEX IF NOT EXISTS appointment_doctor_starts_at_idx  ON appointment (doctor_id, starts_at);
CREATE INDEX IF NOT EXISTS diagnosis_appointment_idx         ON diagnosis (appointment_id);
CREATE INDEX IF NOT EXISTS diagnosis_diagnosed_at_idx        ON diagnosis (diagnosed_at);
CREATE INDEX IF NOT EXISTS invoice_patient_idx               ON invoice (patient_id);
CREATE INDEX IF NOT EXISTS payment_invoice_idx               ON payment (invoice_id);
CREATE INDEX IF NOT EXISTS patient_phone_idx                 ON patient (phone);
CREATE INDEX IF NOT EXISTS patient_date_of_birth_idx         ON patient (date_of_birth);
CREATE INDEX IF NOT EXISTS patient_full_name_trgm_idx        ON patient USING gin ((first_name || ' ' || last_name) gin_trgm_ops);

ANALYZE appointment, diagnosis, invoice, payment, patient;
