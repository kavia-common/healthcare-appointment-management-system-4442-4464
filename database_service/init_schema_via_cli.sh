#!/usr/bin/env bash
# Simple helper to (re)create schema and seed data using the CLI command stored in db_connection.txt.
# This mirrors the steps executed by the agent; safe to re-run (idempotent).

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f db_connection.txt ]; then
  echo "db_connection.txt not found. Start the database via startup.sh first."
  exit 1
fi

CLI_CMD="$(cat db_connection.txt)"
BASE_CMD="${CLI_CMD% myapp}"
# Ensure database exists
${BASE_CMD} -e "CREATE DATABASE IF NOT EXISTS myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Convenience: define a function to run SQL in myapp
run_sql () {
  ${CLI_CMD} -e "$1"
}

# Tables
run_sql "CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  role ENUM('doctor','nurse','admin') NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;"

run_sql "CREATE TABLE IF NOT EXISTS doctors (
  id BIGINT UNSIGNED PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  specialization VARCHAR(255) NULL,
  license_number VARCHAR(100) NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;"

run_sql "CREATE TABLE IF NOT EXISTS patients (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender ENUM('male','female','other') NOT NULL,
  place VARCHAR(255) NULL,
  phone VARCHAR(50) NULL,
  email VARCHAR(255) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_patients_last_name (last_name),
  INDEX idx_patients_phone (phone)
) ENGINE=InnoDB;"

run_sql "CREATE TABLE IF NOT EXISTS doctor_schedules (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  doctor_id BIGINT UNSIGNED NOT NULL,
  schedule_date DATE NOT NULL,
  shift ENUM('morning','afternoon','evening','full_day') NOT NULL DEFAULT 'full_day',
  plan ENUM('operation','outpatient','rounds','off') NOT NULL,
  notes VARCHAR(500) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_doctor_date_shift (doctor_id, schedule_date, shift),
  FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE CASCADE
) ENGINE=InnoDB;"

run_sql "CREATE TABLE IF NOT EXISTS appointments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NOT NULL,
  doctor_id BIGINT UNSIGNED NOT NULL,
  scheduled_at DATETIME NOT NULL,
  reason VARCHAR(500) NULL,
  fee_collected DECIMAL(10,2) DEFAULT 0.00,
  status ENUM('scheduled','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled',
  created_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_appt_doctor_time (doctor_id, scheduled_at),
  INDEX idx_appt_patient_time (patient_id, scheduled_at),
  CONSTRAINT fk_appt_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT fk_appt_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE CASCADE,
  CONSTRAINT fk_appt_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;"

# Seeds
run_sql "INSERT INTO users (email, password_hash, full_name, role)
VALUES
('dr.jane@example.com', '\$2b\$10\$abcdefghijklmnopqrstuv', 'Dr. Jane Doe', 'doctor'),
('nurse.john@example.com', '\$2b\$10\$abcdefghijklmnopqrstuv', 'Nurse John Smith', 'nurse'),
('admin.anna@example.com', '\$2b\$10\$abcdefghijklmnopqrstuv', 'Admin Anna', 'admin')
ON DUPLICATE KEY UPDATE email=VALUES(email);"

run_sql "INSERT INTO doctors (id, user_id, specialization, license_number)
SELECT u.id, u.id, 'General Medicine', 'LIC-12345'
FROM users u WHERE u.email='dr.jane@example.com'
ON DUPLICATE KEY UPDATE specialization=VALUES(specialization), license_number=VALUES(license_number);"

run_sql "INSERT INTO patients (first_name, last_name, date_of_birth, gender, place, phone, email)
VALUES
('Alice', 'Brown', '1985-02-10', 'female', 'Springfield', '555-0001', 'alice.brown@example.com'),
('Bob', 'Green', '1990-07-22', 'male', 'Shelbyville', '555-0002', 'bob.green@example.com')
ON DUPLICATE KEY UPDATE email=VALUES(email);"

run_sql "INSERT INTO doctor_schedules (doctor_id, schedule_date, shift, plan, notes)
SELECT d.id, CURDATE(), 'full_day', 'outpatient', 'Morning OPD'
FROM doctors d
LIMIT 1
ON DUPLICATE KEY UPDATE plan=VALUES(plan), notes=VALUES(notes);"

run_sql "INSERT INTO appointments (patient_id, doctor_id, scheduled_at, reason, fee_collected, status, created_by)
SELECT p.id, d.id, DATE_ADD(CONCAT(CURDATE(), ' 10:00:00'), INTERVAL 0 MINUTE), 'General Checkup', 50.00, 'scheduled',
       (SELECT id FROM users WHERE email='nurse.john@example.com')
FROM patients p JOIN doctors d
ORDER BY p.id ASC
LIMIT 1;"

echo "Schema and seed data applied successfully."
