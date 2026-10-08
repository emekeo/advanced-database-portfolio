SET search_path TO hospital, public;

BEGIN;

TRUNCATE department, salary_grade, staff, staff_profile, patient, disease, patient_condition,
         appointment, ward, bed, admission, diagnosis, lab_test, lab_order, medicine,
         patient_allergy, prescription, prescription_item, stock_movement, invoice,
         invoice_item, payment, payroll_run, payslip, payslip_deduction
RESTART IDENTITY CASCADE;

INSERT INTO department (name) VALUES
    ('General Medicine'),
    ('Paediatrics'),
    ('Obstetrics and Gynaecology'),
    ('Surgery'),
    ('Nursing Services'),
    ('Laboratory'),
    ('Pharmacy'),
    ('Records'),
    ('Finance'),
    ('Human Resources'),
    ('Administration');

INSERT INTO salary_grade (code, title, monthly_basic, housing_allowance, transport_allowance) VALUES
    ('CONMESS-02', 'Medical Officer',            450000.00,  90000.00, 40000.00),
    ('CONMESS-03', 'Senior Medical Officer',     650000.00, 130000.00, 50000.00),
    ('CONMESS-05', 'Consultant',                 950000.00, 190000.00, 70000.00),
    ('CONHESS-09', 'Senior Health Officer',      380000.00,  76000.00, 30000.00),
    ('CONHESS-07', 'Health Officer',             280000.00,  56000.00, 25000.00),
    ('CONHESS-05', 'Officer II',                 180000.00,  36000.00, 20000.00);

INSERT INTO staff (staff_no, first_name, last_name, email, phone, role, department_id, grade_id, hire_date, bank_name, account_no)
SELECT new_staff.staff_no, new_staff.first_name, new_staff.last_name, new_staff.email, new_staff.phone,
       new_staff.role, department.department_id, salary_grade.grade_id, new_staff.hire_date::date,
       new_staff.bank_name, new_staff.account_no
FROM (VALUES
    ('OGH-0001', 'Ese',          'Okoro',     'ese.okoro@ogh.ng',          '08031234501', 'doctor',          'General Medicine',           'CONMESS-03', '2018-02-01', 'First Bank',  '3012345601'),
    ('OGH-0002', 'Chukwuemeka',  'Nwosu',     'chukwuemeka.nwosu@ogh.ng',  '08031234502', 'doctor',          'Paediatrics',                'CONMESS-05', '2012-06-15', 'Access Bank', '0712345602'),
    ('OGH-0003', 'Ifeoma',       'Obi',       'ifeoma.obi@ogh.ng',         '08031234503', 'doctor',          'Obstetrics and Gynaecology', 'CONMESS-05', '2014-09-01', 'GTBank',      '0123456703'),
    ('OGH-0004', 'Oghenekaro',   'Edafe',     'oghenekaro.edafe@ogh.ng',   '08031234504', 'doctor',          'Surgery',                    'CONMESS-03', '2019-01-10', 'Zenith Bank', '2212345604'),
    ('OGH-0005', 'Tolulope',     'Adebayo',   'tolulope.adebayo@ogh.ng',   '08031234505', 'doctor',          'General Medicine',           'CONMESS-02', '2023-03-01', 'UBA',         '2112345605'),
    ('OGH-0006', 'Blessing',     'Ighodaro',  'blessing.ighodaro@ogh.ng',  '08031234506', 'nurse',           'Nursing Services',           'CONHESS-09', '2015-04-20', 'First Bank',  '3012345606'),
    ('OGH-0007', 'Ejiro',        'Omonigho',  'ejiro.omonigho@ogh.ng',     '08031234507', 'nurse',           'Nursing Services',           'CONHESS-07', '2020-08-01', 'Access Bank', '0712345607'),
    ('OGH-0008', 'Grace',        'Ikpeba',    'grace.ikpeba@ogh.ng',       '08031234508', 'nurse',           'Nursing Services',           'CONHESS-07', '2021-11-15', 'GTBank',      '0123456708'),
    ('OGH-0009', 'Kelechi',      'Onyeka',    'kelechi.onyeka@ogh.ng',     '08031234509', 'lab_scientist',   'Laboratory',                 'CONHESS-09', '2016-05-03', 'Zenith Bank', '2212345609'),
    ('OGH-0010', 'Mercy',        'Etaghene',  'mercy.etaghene@ogh.ng',     '08031234510', 'lab_scientist',   'Laboratory',                 'CONHESS-07', '2022-02-14', 'UBA',         '2112345610'),
    ('OGH-0011', 'Emeka',        'Ani',       'emeka.ani@ogh.ng',          '08031234511', 'pharmacist',      'Pharmacy',                   'CONHESS-09', '2017-07-07', 'First Bank',  '3012345611'),
    ('OGH-0012', 'Ruth',         'Okpako',    'ruth.okpako@ogh.ng',        '08031234512', 'pharmacist',      'Pharmacy',                   'CONHESS-07', '2022-09-19', 'Access Bank', '0712345612'),
    ('OGH-0013', 'Joy',          'Ofili',     'joy.ofili@ogh.ng',          '08031234513', 'records_officer', 'Records',                    'CONHESS-05', '2019-10-01', 'GTBank',      '0123456713'),
    ('OGH-0014', 'Samuel',       'Uwadia',    'samuel.uwadia@ogh.ng',      '08031234514', 'billing_officer', 'Finance',                    'CONHESS-05', '2020-01-06', 'Zenith Bank', '2212345614'),
    ('OGH-0015', 'Patience',     'Ugbomah',   'patience.ugbomah@ogh.ng',   '08031234515', 'hr_officer',      'Human Resources',            'CONHESS-07', '2018-03-12', 'UBA',         '2112345615'),
    ('OGH-0016', 'Victor',       'Emuobor',   'victor.emuobor@ogh.ng',     '08031234516', 'admin',           'Administration',             'CONHESS-09', '2013-05-27', 'First Bank',  '3012345616')
) AS new_staff (staff_no, first_name, last_name, email, phone, role, department_name, grade_code, hire_date, bank_name, account_no)
JOIN department   ON department.name   = new_staff.department_name
JOIN salary_grade ON salary_grade.code = new_staff.grade_code;

INSERT INTO staff_profile (staff_id, date_of_birth, sex, home_address, next_of_kin_name, next_of_kin_phone,
                           qualification, specialty, licensing_body, licence_no, licence_expiry)
SELECT staff.staff_id, new_profile.date_of_birth::date, new_profile.sex, new_profile.home_address,
       new_profile.next_of_kin_name, new_profile.next_of_kin_phone, new_profile.qualification,
       new_profile.specialty, new_profile.licensing_body, new_profile.licence_no, new_profile.licence_expiry::date
FROM (VALUES
    ('OGH-0001', '1984-06-11', 'M', '12 Old Lagos Asaba Road, Agbor',   'Rita Okoro',        '08051110001', 'MBBS, FWACP',  'Internal Medicine',  'MDCN',  'MDCN/R/45120',    '2027-12-31'),
    ('OGH-0002', '1975-02-03', 'M', '4 Ime-Obi Street, Agbor',          'Uche Nwosu',        '08051110002', 'MBBS, FMCPaed','Paediatrics',        'MDCN',  'MDCN/R/31876',    '2027-12-31'),
    ('OGH-0003', '1978-10-21', 'F', '7 Boji-Boji Road, Agbor',          'Chidi Obi',         '08051110003', 'MBBS, FWACS',  'Obstetrics',         'MDCN',  'MDCN/R/33410',    '2027-12-31'),
    ('OGH-0004', '1986-12-02', 'M', '19 Agbor-Obi Road, Agbor',         'Efe Edafe',         '08051110004', 'MBBS, FWACS',  'General Surgery',    'MDCN',  'MDCN/R/50237',    '2027-12-31'),
    ('OGH-0005', '1995-04-17', 'F', '3 Ika Close, Agbor',               'Bola Adebayo',      '08051110005', 'MBBS',         'General Practice',   'MDCN',  'MDCN/R/71894',    '2027-12-31'),
    ('OGH-0006', '1983-08-29', 'F', '22 Omumu Street, Agbor',           'Osas Ighodaro',     '08051110006', 'BNSc, RN, RM', 'Midwifery',          'NMCN',  'RN-114562',       '2028-06-30'),
    ('OGH-0007', '1993-01-14', 'F', '9 Alihame Road, Agbor',            'Tega Omonigho',     '08051110007', 'BNSc, RN',     'Medical Nursing',    'NMCN',  'RN-162834',       '2028-06-30'),
    ('OGH-0008', '1996-07-08', 'F', '15 Owa Road, Agbor',               'Paul Ikpeba',       '08051110008', 'RN',           'Paediatric Nursing', 'NMCN',  'RN-171209',       '2026-12-31'),
    ('OGH-0009', '1987-03-25', 'M', '6 Ekuku-Agbor Street, Agbor',      'Adaobi Onyeka',     '08051110009', 'BMLS, AMLSCN', 'Haematology',        'MLSCN', 'MLSCN/04567',     '2027-03-31'),
    ('OGH-0010', '1997-11-30', 'F', '28 Alisimie Road, Agbor',          'Jude Etaghene',     '08051110010', 'BMLS',         'Microbiology',       'MLSCN', 'MLSCN/08812',     '2027-03-31'),
    ('OGH-0011', '1985-09-09', 'M', '11 Orogodo Street, Agbor',         'Nkechi Ani',        '08051110011', 'B.Pharm, FPCPharm', 'Clinical Pharmacy', 'PCN', 'PCN/PS/012345', '2026-12-31'),
    ('OGH-0012', '1996-05-19', 'F', '2 Baleke Street, Agbor',           'Eloho Okpako',      '08051110012', 'B.Pharm',      'Hospital Pharmacy',  'PCN',   'PCN/PS/028761',   '2026-12-31'),
    ('OGH-0013', '1990-12-12', 'F', '30 Idumu-Oza Street, Agbor',       'Ifeanyi Ofili',     '08051110013', 'OND Health Information', NULL,       NULL,    NULL,              NULL),
    ('OGH-0014', '1991-02-22', 'M', '14 Uromi Street, Agbor',           'Grace Uwadia',      '08051110014', 'BSc Accounting', NULL,              NULL,    NULL,              NULL),
    ('OGH-0015', '1988-06-06', 'F', '5 Agbor Technical Road, Agbor',    'Felix Ugbomah',     '08051110015', 'BSc Human Resource Management', NULL, NULL,  NULL,              NULL),
    ('OGH-0016', '1980-09-18', 'M', '1 Hospital Road, Agbor',           'Joy Emuobor',       '08051110016', 'MBA Health Administration', NULL,  NULL,    NULL,              NULL)
) AS new_profile (staff_no, date_of_birth, sex, home_address, next_of_kin_name, next_of_kin_phone,
                  qualification, specialty, licensing_body, licence_no, licence_expiry)
JOIN staff ON staff.staff_no = new_profile.staff_no;

INSERT INTO patient (hospital_no, first_name, last_name, date_of_birth, sex, phone, address,
                     blood_group, genotype, nhis_no, next_of_kin_name, next_of_kin_phone, registered_at) VALUES
    ('OGH/2026/0001', 'Oghenero',  'Akpobome', '1965-03-12', 'M', '08061230001', '8 Ewuru Road, Agbor',          'O+',  'AA', 'NHIS-DT-102345', 'Ufuoma Akpobome', '08071230001', '2026-01-15 10:12+01'),
    ('OGH/2026/0002', 'Chiamaka',  'Okonkwo',  '1992-07-25', 'F', '08061230002', '17 Ime-Obi Street, Agbor',     'A+',  'AS', NULL,             'Obinna Okonkwo',  '08071230002', '2026-02-03 09:40+01'),
    ('OGH/2026/0003', 'Efemena',   'Udoh',     '2019-11-02', 'M', '08061230003', '3 Boji-Boji Road, Agbor',      'B+',  'AA', 'NHIS-DT-208811', 'Joy Udoh',        '08071230003', '2026-03-21 14:05+01'),
    ('OGH/2026/0004', 'Adaeze',    'Nnamdi',   '1996-01-30', 'F', '08061230004', '25 Old Lagos Asaba Road, Agbor','O+', 'AA', NULL,             'Ikenna Nnamdi',   '08071230004', '2026-03-28 11:30+01'),
    ('OGH/2026/0005', 'Tega',      'Omoregie', '1958-09-14', 'M', '08061230005', '40 Agbor-Obi Road, Agbor',     'A-',  'AA', 'NHIS-DT-115090', 'Ese Omoregie',    '08071230005', '2026-04-10 08:55+01'),
    ('OGH/2026/0006', 'Ngozi',     'Ibe',      '2001-05-05', 'F', '08061230006', '6 Alihame Road, Agbor',        'O+',  'SS', NULL,             'Chinedu Ibe',     '08071230006', '2026-05-02 16:20+01'),
    ('OGH/2026/0007', 'Kingsley',  'Ehiede',   '1979-12-20', 'M', '08061230007', '12 Owa Road, Agbor',           'B+',  'AS', NULL,             'Mary Ehiede',     '08071230007', '2026-06-18 10:00+01'),
    ('OGH/2026/0008', 'Rita',      'Okolie',   '1988-04-08', 'F', '08061230008', '9 Orogodo Street, Agbor',      'AB+', 'AA', 'NHIS-DT-301277', 'Tony Okolie',     '08071230008', '2026-07-07 13:45+01'),
    ('OGH/2026/0009', 'Daniel',    'Osagie',   '2015-08-17', 'M', '08061230009', '21 Alisimie Road, Agbor',      'O-',  'AA', NULL,             'Grace Osagie',    '08071230009', '2026-08-11 09:15+01'),
    ('OGH/2026/0010', 'Funmilayo', 'Ajayi',    '1970-02-27', 'F', '08061230010', '5 Baleke Street, Agbor',       'A+',  'AC', 'NHIS-DT-119934', 'Kunle Ajayi',     '08071230010', '2026-09-01 12:10+01');

INSERT INTO disease (name, icd10_code) VALUES
    ('Malaria',                         'B54'),
    ('Typhoid fever',                   'A01.0'),
    ('Hypertension',                    'I10'),
    ('Type 2 diabetes mellitus',        'E11'),
    ('Sickle cell disorder',            'D57'),
    ('Pneumonia',                       'J18'),
    ('Urinary tract infection',         'N39.0'),
    ('Asthma',                          'J45'),
    ('Acute appendicitis',              'K35'),
    ('Single spontaneous delivery',     'O80'),
    ('Acute gastroenteritis',           'A09');

INSERT INTO patient_condition (patient_id, disease_id, condition_type, diagnosed_on, is_active, notes)
SELECT patient.patient_id, disease.disease_id, new_condition.condition_type, new_condition.diagnosed_on::date,
       new_condition.is_active, new_condition.notes
FROM (VALUES
    ('OGH/2026/0001', 'Hypertension',             'chronic',  '2019-03-01', true,  'On amlodipine'),
    ('OGH/2026/0005', 'Hypertension',             'chronic',  '2015-06-10', true,  NULL),
    ('OGH/2026/0005', 'Type 2 diabetes mellitus', 'chronic',  '2017-02-20', true,  'On metformin'),
    ('OGH/2026/0006', 'Sickle cell disorder',     'chronic',  '2002-01-15', true,  'Genotype SS, recurrent bone pain crises'),
    ('OGH/2026/0009', 'Asthma',                   'chronic',  '2020-05-04', true,  'Exercise induced'),
    ('OGH/2026/0010', 'Acute appendicitis',       'surgical', '2026-08-20', false, 'Appendicectomy done 2026-08-21')
) AS new_condition (hospital_no, disease_name, condition_type, diagnosed_on, is_active, notes)
JOIN patient ON patient.hospital_no = new_condition.hospital_no
JOIN disease ON disease.name        = new_condition.disease_name;

INSERT INTO medicine (name, form, strength, unit_price, reorder_level) VALUES
    ('Artemether/Lumefantrine', 'tablet',    '20/120mg',     250.00, 100),
    ('Artesunate',              'injection', '60mg',        2500.00,  20),
    ('Paracetamol',             'tablet',    '500mg',         20.00, 200),
    ('Paracetamol',             'syrup',     '120mg/5ml',    600.00,  20),
    ('Amoxicillin',             'capsule',   '500mg',        150.00, 100),
    ('Ciprofloxacin',           'tablet',    '500mg',        200.00, 100),
    ('Amlodipine',              'tablet',    '5mg',          100.00, 100),
    ('Metformin',               'tablet',    '500mg',         80.00, 100),
    ('Folic acid',              'tablet',    '5mg',           15.00, 100),
    ('Ibuprofen',               'tablet',    '400mg',         40.00, 100),
    ('Ceftriaxone',             'injection', '1g',          1500.00,  30),
    ('Sodium chloride 0.9%',    'infusion',  '500ml',       1200.00,  20),
    ('Salbutamol',              'tablet',    '4mg',           30.00,  50);

INSERT INTO patient_allergy (patient_id, allergen, allergy_type, medicine_id, severity, reaction, recorded_by)
SELECT patient.patient_id, new_allergy.allergen, new_allergy.allergy_type, medicine.medicine_id,
       new_allergy.severity, new_allergy.reaction, staff.staff_id
FROM (VALUES
    ('OGH/2026/0001', 'Amoxicillin', 'drug',          'Amoxicillin', 'capsule', 'severe',   'Generalised rash and facial swelling', 'OGH-0001'),
    ('OGH/2026/0002', 'Groundnut',   'food',          NULL,          NULL,      'moderate', 'Itching and hives',                    'OGH-0005'),
    ('OGH/2026/0008', 'Dust',        'environmental', NULL,          NULL,      'mild',     'Sneezing and watery eyes',             'OGH-0001')
) AS new_allergy (hospital_no, allergen, allergy_type, medicine_name, medicine_form, severity, reaction, recorded_by_staff_no)
JOIN patient    ON patient.hospital_no = new_allergy.hospital_no
JOIN staff      ON staff.staff_no      = new_allergy.recorded_by_staff_no
LEFT JOIN medicine ON medicine.name = new_allergy.medicine_name AND medicine.form = new_allergy.medicine_form;

INSERT INTO ward (name, ward_type, daily_rate) VALUES
    ('Male Medical Ward',   'general',    5000.00),
    ('Female Medical Ward', 'general',    5000.00),
    ('Maternity Ward',      'maternity',  7000.00),
    ('Children''s Ward',    'paediatric', 4000.00),
    ('Surgical Ward',       'surgical',   6000.00),
    ('Intensive Care Unit', 'icu',       25000.00);

INSERT INTO bed (ward_id, bed_no)
SELECT ward.ward_id, 'B' || bed_number
FROM ward
CROSS JOIN generate_series(1, 4) AS bed_number;

INSERT INTO lab_test (code, name, sample_type, price) VALUES
    ('FBC',   'Full blood count',          'blood', 3500.00),
    ('MP',    'Malaria parasite test',     'blood', 1500.00),
    ('WIDAL', 'Widal test',                'blood', 2000.00),
    ('FBS',   'Fasting blood sugar',       'blood', 1500.00),
    ('UA',    'Urinalysis',                'urine', 1500.00),
    ('LFT',   'Liver function test',       'blood', 6000.00),
    ('HBGEN', 'Haemoglobin genotype',      'blood', 2500.00);

INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at, status, reason, created_at)
SELECT patient.patient_id, staff.staff_id, new_appointment.starts_at::timestamptz,
       new_appointment.starts_at::timestamptz + interval '30 minutes',
       new_appointment.status, new_appointment.reason,
       new_appointment.starts_at::timestamptz - interval '2 days'
FROM (VALUES
    ('OGH/2026/0001', 'OGH-0001', '2026-10-01 09:00+01', 'completed', 'Routine blood pressure review'),
    ('OGH/2026/0007', 'OGH-0005', '2026-10-01 10:00+01', 'completed', 'Fever and abdominal pain for 5 days'),
    ('OGH/2026/0003', 'OGH-0002', '2026-10-02 09:00+01', 'completed', 'High fever and vomiting'),
    ('OGH/2026/0002', 'OGH-0005', '2026-10-02 11:00+01', 'completed', 'Headache and fever'),
    ('OGH/2026/0008', 'OGH-0001', '2026-10-03 09:00+01', 'completed', 'Painful urination'),
    ('OGH/2026/0004', 'OGH-0003', '2026-10-03 12:00+01', 'completed', 'Antenatal check at 39 weeks'),
    ('OGH/2026/0005', 'OGH-0001', '2026-10-05 10:00+01', 'completed', 'Cough and breathlessness'),
    ('OGH/2026/0006', 'OGH-0005', '2026-10-05 11:00+01', 'completed', 'Bone pain'),
    ('OGH/2026/0009', 'OGH-0002', '2026-10-06 09:00+01', 'no_show',   'Asthma review'),
    ('OGH/2026/0010', 'OGH-0004', '2026-10-06 10:00+01', 'cancelled', 'Post-surgery follow-up'),
    ('OGH/2026/0001', 'OGH-0001', '2026-10-08 09:00+01', 'scheduled', 'Blood pressure review'),
    ('OGH/2026/0009', 'OGH-0002', '2026-10-08 09:00+01', 'scheduled', 'Asthma review (rebooked)'),
    ('OGH/2026/0010', 'OGH-0004', '2026-10-09 10:00+01', 'scheduled', 'Post-surgery follow-up (rebooked)')
) AS new_appointment (hospital_no, doctor_staff_no, starts_at, status, reason)
JOIN patient ON patient.hospital_no = new_appointment.hospital_no
JOIN staff   ON staff.staff_no      = new_appointment.doctor_staff_no;

INSERT INTO admission (patient_id, bed_id, admitting_doctor_id, admitted_at, discharged_at, reason)
SELECT patient.patient_id, bed.bed_id, staff.staff_id, new_admission.admitted_at::timestamptz,
       new_admission.discharged_at::timestamptz, new_admission.reason
FROM (VALUES
    ('OGH/2026/0003', 'Children''s Ward',  'B1', 'OGH-0002', '2026-10-02 10:00+01', '2026-10-05 12:00+01', 'Severe malaria'),
    ('OGH/2026/0004', 'Maternity Ward',    'B1', 'OGH-0003', '2026-10-04 02:00+01', '2026-10-06 11:00+01', 'Labour at term'),
    ('OGH/2026/0005', 'Male Medical Ward', 'B2', 'OGH-0001', '2026-10-05 11:00+01', NULL,                  'Community-acquired pneumonia')
) AS new_admission (hospital_no, ward_name, bed_no, doctor_staff_no, admitted_at, discharged_at, reason)
JOIN patient ON patient.hospital_no = new_admission.hospital_no
JOIN ward    ON ward.name           = new_admission.ward_name
JOIN bed     ON bed.ward_id = ward.ward_id AND bed.bed_no = new_admission.bed_no
JOIN staff   ON staff.staff_no      = new_admission.doctor_staff_no;

UPDATE bed SET status = 'occupied'
WHERE bed.bed_id IN (SELECT admission.bed_id FROM admission WHERE admission.discharged_at IS NULL);

UPDATE bed SET status = 'maintenance'
FROM ward
WHERE ward.ward_id = bed.ward_id AND ward.name = 'Surgical Ward' AND bed.bed_no = 'B4';

INSERT INTO diagnosis (appointment_id, disease_id, is_primary, notes, diagnosed_at)
SELECT appointment.appointment_id, disease.disease_id, new_diagnosis.is_primary, new_diagnosis.notes,
       appointment.starts_at + interval '20 minutes'
FROM (VALUES
    ('OGH/2026/0001', '2026-10-01 09:00+01', 'Hypertension',             true,  'BP 150/95, continue amlodipine'),
    ('OGH/2026/0007', '2026-10-01 10:00+01', 'Typhoid fever',            true,  'Widal positive, treated as outpatient'),
    ('OGH/2026/0003', '2026-10-02 09:00+01', 'Malaria',                  true,  'MP +++, admitted for IV artesunate'),
    ('OGH/2026/0002', '2026-10-02 11:00+01', 'Malaria',                  true,  'MP +, uncomplicated'),
    ('OGH/2026/0008', '2026-10-03 09:00+01', 'Urinary tract infection',  true,  'Nitrites positive'),
    ('OGH/2026/0005', '2026-10-05 10:00+01', 'Pneumonia',                true,  'Right lower lobe crackles, admitted'),
    ('OGH/2026/0005', '2026-10-05 10:00+01', 'Type 2 diabetes mellitus', false, 'Blood sugar poorly controlled'),
    ('OGH/2026/0006', '2026-10-05 11:00+01', 'Sickle cell disorder',     true,  'Mild vaso-occlusive crisis')
) AS new_diagnosis (hospital_no, starts_at, disease_name, is_primary, notes)
JOIN patient     ON patient.hospital_no = new_diagnosis.hospital_no
JOIN appointment ON appointment.patient_id = patient.patient_id
                AND appointment.starts_at  = new_diagnosis.starts_at::timestamptz
JOIN disease     ON disease.name = new_diagnosis.disease_name;

INSERT INTO diagnosis (admission_id, disease_id, is_primary, notes, diagnosed_at)
SELECT admission.admission_id, disease.disease_id, true, new_diagnosis.notes,
       admission.admitted_at + interval '1 hour'
FROM (VALUES
    ('OGH/2026/0004', 'Single spontaneous delivery', 'Spontaneous vaginal delivery, baby boy 3.4kg'),
    ('OGH/2026/0005', 'Pneumonia',                   'Chest X-ray confirms right lower lobe consolidation')
) AS new_diagnosis (hospital_no, disease_name, notes)
JOIN patient   ON patient.hospital_no = new_diagnosis.hospital_no
JOIN admission ON admission.patient_id = patient.patient_id
JOIN disease   ON disease.name = new_diagnosis.disease_name;

INSERT INTO lab_order (appointment_id, lab_test_id, ordered_by, ordered_at, status, result_value, performed_by, completed_at)
SELECT appointment.appointment_id, lab_test.lab_test_id, appointment.doctor_id,
       appointment.starts_at + interval '15 minutes', 'completed', new_lab_order.result_value,
       staff.staff_id, appointment.starts_at + interval '2 hours'
FROM (VALUES
    ('OGH/2026/0007', '2026-10-01 10:00+01', 'WIDAL', 'S. typhi O 1:160, H 1:160',          'OGH-0009'),
    ('OGH/2026/0007', '2026-10-01 10:00+01', 'FBC',   'WBC 11.2 x10^9/L, Hb 12.8 g/dL',      'OGH-0009'),
    ('OGH/2026/0003', '2026-10-02 09:00+01', 'MP',    'Plasmodium falciparum +++',           'OGH-0010'),
    ('OGH/2026/0002', '2026-10-02 11:00+01', 'MP',    'Plasmodium falciparum +',             'OGH-0010'),
    ('OGH/2026/0008', '2026-10-03 09:00+01', 'UA',    'Leucocytes ++, nitrites positive',    'OGH-0009'),
    ('OGH/2026/0005', '2026-10-05 10:00+01', 'FBC',   'WBC 16.4 x10^9/L, neutrophilia',      'OGH-0009'),
    ('OGH/2026/0005', '2026-10-05 10:00+01', 'FBS',   '8.9 mmol/L',                          'OGH-0010')
) AS new_lab_order (hospital_no, starts_at, test_code, result_value, performed_by_staff_no)
JOIN patient     ON patient.hospital_no = new_lab_order.hospital_no
JOIN appointment ON appointment.patient_id = patient.patient_id
                AND appointment.starts_at  = new_lab_order.starts_at::timestamptz
JOIN lab_test    ON lab_test.code = new_lab_order.test_code
JOIN staff       ON staff.staff_no = new_lab_order.performed_by_staff_no;

INSERT INTO lab_order (admission_id, lab_test_id, ordered_by, ordered_at, status)
SELECT admission.admission_id, lab_test.lab_test_id, admission.admitting_doctor_id,
       '2026-10-07 08:00+01', 'sample_collected'
FROM admission
JOIN patient  ON patient.patient_id = admission.patient_id
JOIN lab_test ON lab_test.code = 'FBC'
WHERE patient.hospital_no = 'OGH/2026/0005';

INSERT INTO prescription (appointment_id, doctor_id, prescribed_at)
SELECT appointment.appointment_id, appointment.doctor_id, appointment.starts_at + interval '25 minutes'
FROM appointment
JOIN patient ON patient.patient_id = appointment.patient_id
WHERE (patient.hospital_no, appointment.starts_at) IN (
    ('OGH/2026/0001', '2026-10-01 09:00+01'::timestamptz),
    ('OGH/2026/0007', '2026-10-01 10:00+01'::timestamptz),
    ('OGH/2026/0002', '2026-10-02 11:00+01'::timestamptz),
    ('OGH/2026/0008', '2026-10-03 09:00+01'::timestamptz),
    ('OGH/2026/0006', '2026-10-05 11:00+01'::timestamptz));

INSERT INTO prescription (admission_id, doctor_id, prescribed_at, notes)
SELECT admission.admission_id, admission.admitting_doctor_id, admission.admitted_at + interval '30 minutes',
       'Inpatient medication chart'
FROM admission
JOIN patient ON patient.patient_id = admission.patient_id
WHERE patient.hospital_no IN ('OGH/2026/0003', 'OGH/2026/0005');

INSERT INTO prescription_item (prescription_id, medicine_id, dosage, frequency, duration_days, quantity, quantity_dispensed)
SELECT prescription.prescription_id, medicine.medicine_id, new_item.dosage, new_item.frequency,
       new_item.duration_days, new_item.quantity, new_item.quantity_dispensed
FROM (VALUES
    ('OGH/2026/0001', 'Amlodipine',              'tablet',    '1 tablet',   'once daily',        30, 30, 30),
    ('OGH/2026/0007', 'Ciprofloxacin',           'tablet',    '1 tablet',   'twice daily',        7, 14, 14),
    ('OGH/2026/0007', 'Paracetamol',             'tablet',    '2 tablets',  'three times daily',  5, 30, 30),
    ('OGH/2026/0002', 'Artemether/Lumefantrine', 'tablet',    '4 tablets',  'twice daily',        3, 24, 24),
    ('OGH/2026/0002', 'Paracetamol',             'tablet',    '2 tablets',  'three times daily',  3, 18, 18),
    ('OGH/2026/0008', 'Ciprofloxacin',           'tablet',    '1 tablet',   'twice daily',        5, 10, 10),
    ('OGH/2026/0006', 'Folic acid',              'tablet',    '1 tablet',   'once daily',        30, 30, 30),
    ('OGH/2026/0006', 'Ibuprofen',               'tablet',    '1 tablet',   'three times daily',  5, 15,  0),
    ('OGH/2026/0003', 'Artesunate',              'injection', '60mg IV',    'at 0, 12, 24 hours', 1,  3,  3),
    ('OGH/2026/0003', 'Paracetamol',             'syrup',     '10ml',       'three times daily',  3,  1,  1),
    ('OGH/2026/0003', 'Sodium chloride 0.9%',    'infusion',  '500ml IV',   'twice daily',        1,  2,  2),
    ('OGH/2026/0005', 'Ceftriaxone',             'injection', '1g IV',      'once daily',         7,  7,  3),
    ('OGH/2026/0005', 'Metformin',               'tablet',    '1 tablet',   'twice daily',       30, 60, 60)
) AS new_item (hospital_no, medicine_name, medicine_form, dosage, frequency, duration_days, quantity, quantity_dispensed)
JOIN patient      ON patient.hospital_no = new_item.hospital_no
JOIN medicine     ON medicine.name = new_item.medicine_name AND medicine.form = new_item.medicine_form
JOIN prescription ON prescription.prescription_id = (
        SELECT prescription.prescription_id
        FROM prescription
        LEFT JOIN appointment ON appointment.appointment_id = prescription.appointment_id
        LEFT JOIN admission   ON admission.admission_id     = prescription.admission_id
        WHERE COALESCE(appointment.patient_id, admission.patient_id) = patient.patient_id
        ORDER BY prescription.prescribed_at DESC
        LIMIT 1);

INSERT INTO stock_movement (medicine_id, movement_type, quantity, supplier_ref, recorded_by, recorded_at)
SELECT medicine.medicine_id, 'received', new_stock.quantity, new_stock.supplier_ref, staff.staff_id, '2026-09-25 10:00+01'
FROM (VALUES
    ('Artemether/Lumefantrine', 'tablet',    500,  'SUP-2026-0912'),
    ('Artesunate',              'injection',  50,  'SUP-2026-0912'),
    ('Paracetamol',             'tablet',   1000,  'SUP-2026-0913'),
    ('Paracetamol',             'syrup',      60,  'SUP-2026-0913'),
    ('Amoxicillin',             'capsule',   400,  'SUP-2026-0913'),
    ('Ciprofloxacin',           'tablet',    300,  'SUP-2026-0914'),
    ('Amlodipine',              'tablet',    300,  'SUP-2026-0914'),
    ('Metformin',               'tablet',    400,  'SUP-2026-0914'),
    ('Folic acid',              'tablet',    500,  'SUP-2026-0915'),
    ('Ibuprofen',               'tablet',    300,  'SUP-2026-0915'),
    ('Ceftriaxone',             'injection',  80,  'SUP-2026-0915'),
    ('Sodium chloride 0.9%',    'infusion',   40,  'SUP-2026-0916'),
    ('Salbutamol',              'tablet',     40,  'SUP-2026-0916')
) AS new_stock (medicine_name, medicine_form, quantity, supplier_ref)
JOIN medicine ON medicine.name = new_stock.medicine_name AND medicine.form = new_stock.medicine_form
JOIN staff    ON staff.staff_no = 'OGH-0011';

INSERT INTO stock_movement (medicine_id, movement_type, quantity, prescription_id, recorded_by, recorded_at)
SELECT prescription_item.medicine_id, 'dispensed', -prescription_item.quantity_dispensed,
       prescription_item.prescription_id, staff.staff_id, prescription.prescribed_at + interval '30 minutes'
FROM prescription_item
JOIN prescription ON prescription.prescription_id = prescription_item.prescription_id
JOIN staff        ON staff.staff_no = 'OGH-0012'
WHERE prescription_item.quantity_dispensed > 0;

INSERT INTO stock_movement (medicine_id, movement_type, quantity, recorded_by, recorded_at)
SELECT medicine.medicine_id, new_stock.movement_type, new_stock.quantity, staff.staff_id, new_stock.recorded_at::timestamptz
FROM (VALUES
    ('Paracetamol', 'tablet',    'expired',    -20, '2026-09-30 16:00+01'),
    ('Ceftriaxone', 'injection', 'adjustment',  -2, '2026-10-04 09:00+01')
) AS new_stock (medicine_name, medicine_form, movement_type, quantity, recorded_at)
JOIN medicine ON medicine.name = new_stock.medicine_name AND medicine.form = new_stock.medicine_form
JOIN staff    ON staff.staff_no = 'OGH-0011';

UPDATE medicine
SET quantity_on_hand = (SELECT COALESCE(SUM(stock_movement.quantity), 0)
                        FROM stock_movement
                        WHERE stock_movement.medicine_id = medicine.medicine_id);

INSERT INTO invoice (invoice_no, patient_id, issued_at, due_date, status)
SELECT new_invoice.invoice_no, patient.patient_id, new_invoice.issued_at::timestamptz,
       new_invoice.due_date::date, new_invoice.status
FROM (VALUES
    ('INV-2026-000001', 'OGH/2026/0001', '2026-10-01 10:00+01', '2026-10-01', 'paid'),
    ('INV-2026-000002', 'OGH/2026/0007', '2026-10-01 13:00+01', '2026-10-01', 'paid'),
    ('INV-2026-000003', 'OGH/2026/0002', '2026-10-02 14:00+01', '2026-10-16', 'part_paid'),
    ('INV-2026-000004', 'OGH/2026/0008', '2026-10-03 12:00+01', '2026-10-17', 'issued'),
    ('INV-2026-000005', 'OGH/2026/0003', '2026-10-05 12:30+01', '2026-10-19', 'paid'),
    ('INV-2026-000006', 'OGH/2026/0006', '2026-10-05 12:00+01', '2026-10-05', 'paid'),
    ('INV-2026-000007', 'OGH/2026/0004', '2026-10-06 11:30+01', '2026-10-20', 'paid')
) AS new_invoice (invoice_no, hospital_no, issued_at, due_date, status)
JOIN patient ON patient.hospital_no = new_invoice.hospital_no;

INSERT INTO invoice_item (invoice_id, line_no, item_type, description, quantity, unit_price)
SELECT invoice.invoice_id, new_item.line_no, new_item.item_type, new_item.description, new_item.quantity, new_item.unit_price
FROM (VALUES
    ('INV-2026-000001', 1, 'consultation', 'Consultation - General Medicine',          1, 5000.00),
    ('INV-2026-000001', 2, 'medicine',     'Amlodipine 5mg tablet',                   30,  100.00),
    ('INV-2026-000002', 1, 'consultation', 'Consultation - General Medicine',          1, 5000.00),
    ('INV-2026-000002', 2, 'lab',          'Widal test',                               1, 2000.00),
    ('INV-2026-000002', 3, 'lab',          'Full blood count',                         1, 3500.00),
    ('INV-2026-000002', 4, 'medicine',     'Ciprofloxacin 500mg tablet',              14,  200.00),
    ('INV-2026-000002', 5, 'medicine',     'Paracetamol 500mg tablet',                30,   20.00),
    ('INV-2026-000003', 1, 'consultation', 'Consultation - General Medicine',          1, 5000.00),
    ('INV-2026-000003', 2, 'lab',          'Malaria parasite test',                    1, 1500.00),
    ('INV-2026-000003', 3, 'medicine',     'Artemether/Lumefantrine 20/120mg tablet', 24,  250.00),
    ('INV-2026-000003', 4, 'medicine',     'Paracetamol 500mg tablet',                18,   20.00),
    ('INV-2026-000004', 1, 'consultation', 'Consultation - General Medicine',          1, 5000.00),
    ('INV-2026-000004', 2, 'lab',          'Urinalysis',                               1, 1500.00),
    ('INV-2026-000004', 3, 'medicine',     'Ciprofloxacin 500mg tablet',              10,  200.00),
    ('INV-2026-000005', 1, 'consultation', 'Consultation - Paediatrics',               1, 5000.00),
    ('INV-2026-000005', 2, 'lab',          'Malaria parasite test',                    1, 1500.00),
    ('INV-2026-000005', 3, 'bed',          'Children''s Ward - 3 days',                3, 4000.00),
    ('INV-2026-000005', 4, 'medicine',     'Artesunate 60mg injection',                3, 2500.00),
    ('INV-2026-000005', 5, 'medicine',     'Paracetamol 120mg/5ml syrup',              1,  600.00),
    ('INV-2026-000005', 6, 'medicine',     'Sodium chloride 0.9% 500ml infusion',      2, 1200.00),
    ('INV-2026-000006', 1, 'consultation', 'Consultation - General Medicine',          1, 5000.00),
    ('INV-2026-000006', 2, 'medicine',     'Folic acid 5mg tablet',                   30,   15.00),
    ('INV-2026-000007', 1, 'consultation', 'Antenatal consultation',                   1, 5000.00),
    ('INV-2026-000007', 2, 'procedure',    'Normal delivery',                          1, 50000.00),
    ('INV-2026-000007', 3, 'bed',          'Maternity Ward - 2 days',                  2, 7000.00)
) AS new_item (invoice_no, line_no, item_type, description, quantity, unit_price)
JOIN invoice ON invoice.invoice_no = new_item.invoice_no;

INSERT INTO payment (invoice_id, amount, method, reference, paid_at, received_by)
SELECT invoice.invoice_id, new_payment.amount, new_payment.method, new_payment.reference,
       new_payment.paid_at::timestamptz, staff.staff_id
FROM (VALUES
    ('INV-2026-000001',  8000.00, 'pos',      'POS-7781203', '2026-10-01 10:05+01'),
    ('INV-2026-000002', 13900.00, 'transfer', 'TRF-55120931', '2026-10-01 13:20+01'),
    ('INV-2026-000003',  8000.00, 'cash',     NULL,          '2026-10-02 14:10+01'),
    ('INV-2026-000005', 20000.00, 'nhis',     'NHIS-CLM-88012', '2026-10-05 12:40+01'),
    ('INV-2026-000005',  9000.00, 'cash',     NULL,          '2026-10-05 12:45+01'),
    ('INV-2026-000006',  5450.00, 'cash',     NULL,          '2026-10-05 12:05+01'),
    ('INV-2026-000007', 69000.00, 'transfer', 'TRF-55190744', '2026-10-06 11:45+01')
) AS new_payment (invoice_no, amount, method, reference, paid_at)
JOIN invoice ON invoice.invoice_no = new_payment.invoice_no
JOIN staff   ON staff.staff_no = 'OGH-0014';

INSERT INTO payroll_run (period_month, status, created_at, approved_by)
SELECT '2026-09-01', 'paid', '2026-09-25 09:00+01', staff.staff_id
FROM staff
WHERE staff.staff_no = 'OGH-0016';

INSERT INTO payslip (payroll_run_id, staff_id, basic_pay, housing_allowance, transport_allowance)
SELECT payroll_run.payroll_run_id, staff.staff_id, salary_grade.monthly_basic,
       salary_grade.housing_allowance, salary_grade.transport_allowance
FROM staff
JOIN salary_grade ON salary_grade.grade_id = staff.grade_id
CROSS JOIN payroll_run
WHERE payroll_run.period_month = '2026-09-01' AND staff.status = 'active';

INSERT INTO payslip_deduction (payslip_id, deduction_type, amount)
SELECT payslip.payslip_id, deduction.deduction_type,
       ROUND(CASE deduction.deduction_type
                 WHEN 'paye'    THEN payslip.gross_pay * 0.07
                 WHEN 'pension' THEN payslip.gross_pay * 0.08
                 WHEN 'nhf'     THEN payslip.basic_pay * 0.025
             END, 2)
FROM payslip
CROSS JOIN (VALUES ('paye'), ('pension'), ('nhf')) AS deduction (deduction_type);

UPDATE payslip
SET total_deductions = (SELECT SUM(payslip_deduction.amount)
                        FROM payslip_deduction
                        WHERE payslip_deduction.payslip_id = payslip.payslip_id);

COMMIT;
