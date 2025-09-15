# Healthcare Appointment Management System - MySQL Schema

This document describes the initial MySQL schema and the seed data created for the healthcare appointment management system.

Database: `myapp` (utf8mb4 / utf8mb4_unicode_ci)

Tables created:
1) users
   - id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY
   - email VARCHAR(255) UNIQUE NOT NULL
   - password_hash VARCHAR(255) NOT NULL
   - full_name VARCHAR(255) NOT NULL
   - role ENUM('doctor','nurse','admin') NOT NULL
   - is_active TINYINT(1) NOT NULL DEFAULT 1
   - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   - updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

2) doctors
   - id BIGINT UNSIGNED PRIMARY KEY
   - user_id BIGINT UNSIGNED UNIQUE NOT NULL
   - specialization VARCHAR(255) NULL
   - license_number VARCHAR(100) NULL
   - Foreign keys:
     - (user_id) -> users(id) ON DELETE CASCADE
     - (id) -> users(id) ON DELETE CASCADE
   Notes:
   - 1:1 relationship with users for role=doctor by sharing the same id as users.id

3) patients
   - id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY
   - first_name VARCHAR(100) NOT NULL
   - last_name VARCHAR(100) NOT NULL
   - date_of_birth DATE NOT NULL
   - gender ENUM('male','female','other') NOT NULL
   - place VARCHAR(255) NULL
   - phone VARCHAR(50) NULL
   - email VARCHAR(255) NULL
   - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   - updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
   - Indexes: (last_name), (phone)

4) doctor_schedules
   - id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY
   - doctor_id BIGINT UNSIGNED NOT NULL
   - schedule_date DATE NOT NULL
   - shift ENUM('morning','afternoon','evening','full_day') NOT NULL DEFAULT 'full_day'
   - plan ENUM('operation','outpatient','rounds','off') NOT NULL
   - notes VARCHAR(500) NULL
   - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   - updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
   - Unique: (doctor_id, schedule_date, shift)
   - Foreign keys: (doctor_id) -> doctors(id) ON DELETE CASCADE

5) appointments
   - id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY
   - patient_id BIGINT UNSIGNED NOT NULL
   - doctor_id BIGINT UNSIGNED NOT NULL
   - scheduled_at DATETIME NOT NULL
   - reason VARCHAR(500) NULL
   - fee_collected DECIMAL(10,2) DEFAULT 0.00
   - status ENUM('scheduled','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled'
   - created_by BIGINT UNSIGNED NULL
   - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   - updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
   - Indexes:
     - (doctor_id, scheduled_at)
     - (patient_id, scheduled_at)
   - Foreign keys:
     - (patient_id) -> patients(id) ON DELETE CASCADE
     - (doctor_id) -> doctors(id) ON DELETE CASCADE
     - (created_by) -> users(id) ON DELETE SET NULL

Seed data inserted:
- Users
  - dr.jane@example.com (role=doctor)
  - nurse.john@example.com (role=nurse)
  - admin.anna@example.com (role=admin)
  - Note: password_hash values are placeholders; replace with real bcrypt hashes in production.

- Doctor
  - Linked 1:1 to dr.jane@example.com
  - specialization: General Medicine, license_number: LIC-12345

- Patients
  - Alice Brown (1985-02-10, female)
  - Bob Green (1990-07-22, male)

- Doctor Schedule
  - Today, full_day, plan=outpatient, notes="Morning OPD" for Dr. Jane

- Appointment
  - Patient (first in list) with Dr. Jane at 10:00 today
  - reason="General Checkup", fee_collected=50.00, status=scheduled
  - created_by=nurse.john@example.com

How to connect:
- Connection command stored in: database_service/db_connection.txt
- Example:
  mysql -u appuser -pdbuser123 -h localhost -P 5000 myapp

Re-initialization notes:
- The schema and seed were executed via CLI (no .sql files created).
- If you need to reset, you can drop the `myapp` database and rerun the schema steps, or use the backup/restore scripts provided:
  - database_service/backup_db.sh
  - database_service/restore_db.sh

Environment for DB Viewer:
- Source the env file: source database_service/db_visualizer/mysql.env
- Start the viewer: (from db_visualizer directory) npm start
