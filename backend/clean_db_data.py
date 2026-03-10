import sqlite3
import os

DB_FILE = "solitary.db"

def clean_database():
    if not os.path.exists(DB_FILE):
        print(f"Database file {DB_FILE} not found.")
        return

    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    try:
        # 获取所有表名
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()

        print("Cleaning data from tables...")
        for table in tables:
            table_name = table[0]
            # 跳过 sqlite_sequence 表（用于自增ID）
            if table_name == "sqlite_sequence":
                continue
                
            print(f"Deleting data from {table_name}...")
            cursor.execute(f"DELETE FROM {table_name};")
            
            # 重置自增ID (可选)
            # cursor.execute(f"DELETE FROM sqlite_sequence WHERE name='{table_name}';")

        conn.commit()
        print("All data deleted successfully.")

    except Exception as e:
        print(f"Error cleaning database: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    confirmation = input("Are you sure you want to DELETE ALL DATA from solitary.db? (yes/no): ")
    if confirmation.lower() == "yes":
        clean_database()
    else:
        print("Operation cancelled.")
