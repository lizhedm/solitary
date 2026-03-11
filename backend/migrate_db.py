import sqlite3
import os

db_path = "solitary.db"

if not os.path.exists(db_path):
    print(f"Database {db_path} not found.")
else:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("Migrating messages table...")
    
    # Check if sender_hike_id exists
    try:
        cursor.execute("SELECT sender_hike_id FROM messages LIMIT 1")
        print("sender_hike_id already exists.")
    except sqlite3.OperationalError:
        print("Adding sender_hike_id column...")
        cursor.execute("ALTER TABLE messages ADD COLUMN sender_hike_id INTEGER")
        
    # Check if receiver_hike_id exists
    try:
        cursor.execute("SELECT receiver_hike_id FROM messages LIMIT 1")
        print("receiver_hike_id already exists.")
    except sqlite3.OperationalError:
        print("Adding receiver_hike_id column...")
        cursor.execute("ALTER TABLE messages ADD COLUMN receiver_hike_id INTEGER")

    # Check if is_read exists
    try:
        cursor.execute("SELECT is_read FROM messages LIMIT 1")
        print("is_read already exists.")
    except sqlite3.OperationalError:
        print("Adding is_read column...")
        cursor.execute("ALTER TABLE messages ADD COLUMN is_read BOOLEAN DEFAULT 0")
    
    conn.commit()
    conn.close()
    print("Migration completed.")
