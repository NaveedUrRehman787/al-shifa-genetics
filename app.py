from flask import Flask, render_template, request, jsonify, send_file
import sqlite3
import os
import datetime
import random
import io
import pandas as pd

app = Flask(__name__)
app.secret_key = os.urandom(24)

DB_FILE = "genetics.db"
EXCEL_FILE = "family_data.xlsx"

COLUMNS = [
    "FamilyID", "IndividualID", "MRNumber", "Name", "CNIC", "Age", "Gender",
    "BatchNumber", "Doctor", "Department", "Disease", "Sequencing",
    "SampleCollected", "Affected", "Consanguinity", "Category", "AnalysisStatus"
]

# ─── Database Helpers ─────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")  # Better concurrency
    return conn

def init_db():
    """Create tables if they don't exist, then auto-migrate from Excel if needed."""
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS families (
                FamilyID  TEXT PRIMARY KEY,
                Suffix    TEXT UNIQUE NOT NULL,
                CreatedAt TEXT DEFAULT (datetime('now','localtime'))
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS individuals (
                IndividualID    TEXT PRIMARY KEY,
                FamilyID        TEXT NOT NULL,
                MRNumber        TEXT,
                Name            TEXT,
                CNIC            TEXT,
                Age             REAL,
                Gender          TEXT,
                BatchNumber     REAL,
                Doctor          TEXT,
                Department      TEXT,
                Disease         TEXT,
                Sequencing      TEXT,
                SampleCollected TEXT,
                Affected        TEXT DEFAULT 'Yes',
                Consanguinity   TEXT DEFAULT 'No',
                Category        TEXT DEFAULT 'Private',
                AnalysisStatus  TEXT DEFAULT 'Individual Complete - Ready for Bioinformatics',
                CreatedAt       TEXT DEFAULT (datetime('now','localtime')),
                FOREIGN KEY (FamilyID) REFERENCES families(FamilyID)
            )
        """)
        conn.commit()

    # Auto-migrate from Excel if DB is empty
    with get_db() as conn:
        count = conn.execute("SELECT COUNT(*) FROM individuals").fetchone()[0]
        if count == 0 and os.path.exists(EXCEL_FILE):
            migrate_from_excel()

def migrate_from_excel():
    """One-time migration: import all rows from family_data.xlsx into SQLite."""
    try:
        df = pd.read_excel(EXCEL_FILE)
        for col in COLUMNS:
            if col not in df.columns:
                df[col] = ""
        df['Age'] = pd.to_numeric(df['Age'], errors='coerce')
        df['BatchNumber'] = pd.to_numeric(df['BatchNumber'], errors='coerce')
        df = df.fillna("")

        with get_db() as conn:
            migrated_families = set()
            for _, row in df.iterrows():
                fam_id = str(row['FamilyID']).strip()
                parts = fam_id.split('-')
                suffix = parts[-1] if len(parts) >= 3 else fam_id

                if fam_id not in migrated_families:
                    conn.execute(
                        "INSERT OR IGNORE INTO families (FamilyID, Suffix) VALUES (?, ?)",
                        (fam_id, suffix)
                    )
                    migrated_families.add(fam_id)

                ind_id = str(row['IndividualID']).strip()
                age = row['Age'] if row['Age'] != "" else None
                batch = row['BatchNumber'] if row['BatchNumber'] != "" else None

                conn.execute("""
                    INSERT OR IGNORE INTO individuals
                    (IndividualID, FamilyID, MRNumber, Name, CNIC, Age, Gender,
                     BatchNumber, Doctor, Department, Disease, Sequencing,
                     SampleCollected, Affected, Consanguinity, Category, AnalysisStatus)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, (
                    ind_id, fam_id,
                    str(row['MRNumber']), str(row['Name']), str(row['CNIC']),
                    age, str(row['Gender']), batch,
                    str(row['Doctor']), str(row['Department']), str(row['Disease']),
                    str(row['Sequencing']), str(row['SampleCollected']),
                    str(row['Affected']) or 'Yes',
                    str(row['Consanguinity']) or 'No',
                    str(row['Category']) or 'Private',
                    str(row['AnalysisStatus']) or 'Individual Complete - Ready for Bioinformatics'
                ))
            conn.commit()
        print(f"[OK] Migrated {len(df)} records from Excel to SQLite.")
    except Exception as e:
        print(f"[ERROR] Migration error: {e}")

def row_to_dict(row):
    """Convert a sqlite3.Row to a plain dict, replacing None with empty string."""
    d = dict(row)
    return {k: (v if v is not None else "") for k, v in d.items()}

# ─── Family ID Generation ──────────────────────────────────────────────────────

def generate_unique_family_id():
    """Generate a Family ID with a 4-digit suffix guaranteed unique in the DB."""
    with get_db() as conn:
        existing_suffixes = {
            r[0] for r in conn.execute("SELECT Suffix FROM families").fetchall()
        }

    while True:
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        short_id = str(random.randint(1000, 9999))
        if short_id not in existing_suffixes:
            return f"FAM-{timestamp}-{short_id}"

# ─── Routes ───────────────────────────────────────────────────────────────────

@app.route('/')
def dashboard():
    with get_db() as conn:
        total_families   = conn.execute("SELECT COUNT(*) FROM families").fetchone()[0]
        total_individuals = conn.execute("SELECT COUNT(*) FROM individuals").fetchone()[0]
        total_diseases   = conn.execute("SELECT COUNT(DISTINCT Disease) FROM individuals WHERE Disease != ''").fetchone()[0]
        total_doctors    = conn.execute("SELECT COUNT(DISTINCT Doctor) FROM individuals WHERE Doctor != ''").fetchone()[0]

    return render_template('dashboard.html',
                           total_families=total_families,
                           total_individuals=total_individuals,
                           total_diseases=total_diseases,
                           total_doctors=total_doctors)

@app.route('/add_family')
def add_family():
    with get_db() as conn:
        families = [r[0] for r in conn.execute("SELECT FamilyID FROM families ORDER BY CreatedAt DESC").fetchall()]
    return render_template('add_family.html', families=families)

@app.route('/api/reserve_family_id')
def reserve_family_id():
    new_id = generate_unique_family_id()
    return jsonify({"family_id": new_id})

@app.route('/api/submit_family', methods=['POST'])
def submit_family():
    data    = request.json
    mode    = data.get('mode')
    members = data.get('members', [])

    if not members:
        return jsonify({"success": False, "message": "No members provided."})

    with get_db() as conn:
        if mode == 'new':
            family_id = data.get('reserved_family_id') or generate_unique_family_id()
            parts = family_id.split('-')
            suffix = parts[-1] if len(parts) >= 3 else family_id
            try:
                conn.execute(
                    "INSERT INTO families (FamilyID, Suffix) VALUES (?, ?)",
                    (family_id, suffix)
                )
            except sqlite3.IntegrityError:
                return jsonify({"success": False, "message": f"Family ID {family_id} already exists. Please try again."})
        else:
            family_id = data.get('existing_family_id')
            exists = conn.execute("SELECT 1 FROM families WHERE FamilyID=?", (family_id,)).fetchone()
            if not exists:
                return jsonify({"success": False, "message": "Invalid family selected."})

        # Next individual number for this family
        start_num = conn.execute(
            "SELECT COUNT(*) FROM individuals WHERE FamilyID=?", (family_id,)
        ).fetchone()[0] + 1

        try:
            for i, member in enumerate(members):
                ind_id = f"{family_id}-IND{str(start_num + i).zfill(3)}"
                age    = member.get("Age") or None
                batch  = member.get("BatchNumber") or None
                conn.execute("""
                    INSERT INTO individuals
                    (IndividualID, FamilyID, MRNumber, Name, CNIC, Age, Gender,
                     BatchNumber, Doctor, Department, Disease, Sequencing,
                     SampleCollected, Affected, Consanguinity, Category, AnalysisStatus)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, (
                    ind_id, family_id,
                    member.get("MRNumber", ""), member.get("Name", ""),
                    member.get("CNIC", ""), age, member.get("Gender", ""),
                    batch, member.get("Doctor", ""), member.get("Department", ""),
                    member.get("Disease", ""), member.get("Sequencing", ""),
                    member.get("SampleCollected", ""),
                    member.get("Affected", "Yes"), member.get("Consanguinity", "No"),
                    member.get("Category", "Private"),
                    "Individual Complete - Ready for Bioinformatics"
                ))
            conn.commit()
        except Exception as e:
            return jsonify({"success": False, "message": f"Error saving data: {e}"})

    return jsonify({"success": True,
                    "message": f"Family submitted successfully! ID: {family_id}",
                    "family_id": family_id})

@app.route('/view_records')
def view_records():
    return render_template('view_records.html')

@app.route('/api/records')
def api_records():
    with get_db() as conn:
        rows = conn.execute(f"SELECT {', '.join(COLUMNS)} FROM individuals ORDER BY FamilyID, IndividualID").fetchall()
    return jsonify([row_to_dict(r) for r in rows])

@app.route('/api/diseases')
def api_diseases():
    department = request.args.get('department', '')
    with get_db() as conn:
        if department:
            rows = conn.execute(
                "SELECT DISTINCT Disease FROM individuals WHERE Department=? AND Disease != '' ORDER BY Disease",
                (department,)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT DISTINCT Disease FROM individuals WHERE Disease != '' ORDER BY Disease"
            ).fetchall()
    return jsonify([r[0] for r in rows])

@app.route('/remaining_analysis')
def remaining_analysis():
    return render_template('remaining_analysis.html')

@app.route('/api/analysis_queue')
def analysis_queue():
    READY   = "Individual Complete - Ready for Bioinformatics"
    DONE    = "Bioinformatics Analysis Complete"
    with get_db() as conn:
        queue    = conn.execute(
            f"SELECT {', '.join(COLUMNS)} FROM individuals WHERE AnalysisStatus=?", (READY,)
        ).fetchall()
        pending  = len(queue)
        completed = conn.execute("SELECT COUNT(*) FROM individuals WHERE AnalysisStatus=?", (DONE,)).fetchone()[0]
        total     = conn.execute("SELECT COUNT(*) FROM individuals").fetchone()[0]

    return jsonify({
        "queue": [row_to_dict(r) for r in queue],
        "stats": {"pending": pending, "completed": completed, "total": total}
    })

@app.route('/api/start_analysis', methods=['POST'])
def start_analysis():
    data        = request.json
    ind_id      = data.get('individual_id')
    analysis_type = data.get('analysis_type')

    if not ind_id or not analysis_type:
        return jsonify({"success": False, "message": "Missing parameters."})

    with get_db() as conn:
        result = conn.execute(
            "UPDATE individuals SET AnalysisStatus='Bioinformatics Analysis Complete' WHERE IndividualID=?",
            (ind_id,)
        )
        conn.commit()
        if result.rowcount == 0:
            return jsonify({"success": False, "message": "Individual not found."})

    return jsonify({"success": True, "message": f"Analysis marked complete for {ind_id}."})

@app.route('/api/update_individual', methods=['POST'])
def update_individual():
    data   = request.json
    ind_id = data.get('individual_id')
    if not ind_id:
        return jsonify({"success": False, "message": "Missing individual ID."})

    age   = data.get('Age')   or None
    batch = data.get('BatchNumber') or None

    with get_db() as conn:
        result = conn.execute("""
            UPDATE individuals SET
                MRNumber=?, Name=?, CNIC=?, Age=?, Gender=?,
                BatchNumber=?, Doctor=?, Department=?, Disease=?,
                Sequencing=?, SampleCollected=?, Affected=?,
                Consanguinity=?, Category=?, AnalysisStatus=?
            WHERE IndividualID=?
        """, (
            data.get('MRNumber',''), data.get('Name',''), data.get('CNIC',''),
            age, data.get('Gender',''), batch,
            data.get('Doctor',''), data.get('Department',''), data.get('Disease',''),
            data.get('Sequencing',''), data.get('SampleCollected',''),
            data.get('Affected','Yes'), data.get('Consanguinity','No'),
            data.get('Category','Private'), data.get('AnalysisStatus',''),
            ind_id
        ))
        conn.commit()
        if result.rowcount == 0:
            return jsonify({"success": False, "message": "Record not found."})

    return jsonify({"success": True, "message": f"Record {ind_id} updated successfully."})

@app.route('/settings')
def settings():
    with get_db() as conn:
        db_size_bytes = os.path.getsize(DB_FILE) if os.path.exists(DB_FILE) else 0
        total = conn.execute("SELECT COUNT(*) FROM individuals").fetchone()[0]
    db_size_kb = round(db_size_bytes / 1024, 1)
    return render_template('settings.html', db_file=DB_FILE,
                           db_size=db_size_kb, total_records=total)

@app.route('/export_data')
def export_data():
    with get_db() as conn:
        rows = conn.execute(f"SELECT {', '.join(COLUMNS)} FROM individuals ORDER BY FamilyID, IndividualID").fetchall()
    df = pd.DataFrame([dict(r) for r in rows], columns=COLUMNS)
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        df.to_excel(writer, index=False, sheet_name='Genetics Data')
    output.seek(0)
    filename = f"family_genetics_data_{datetime.datetime.now().strftime('%Y%m%d_%H%M')}.xlsx"
    return send_file(output, as_attachment=True, download_name=filename,
                     mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

@app.route('/api/clear_data', methods=['POST'])
def clear_data():
    with get_db() as conn:
        conn.execute("DELETE FROM individuals")
        conn.execute("DELETE FROM families")
        conn.commit()
    return jsonify({"success": True, "message": "All data cleared successfully."})

# ─── Boot ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    init_db()
    app.run(debug=True, port=8000)
