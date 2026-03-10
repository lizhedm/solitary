import os
import sys

# 将backend目录添加到路径，确保可以导入app模块
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import database
from app.models import User, HikingRecord, Message, Feedback, Friendship

DB_FILE = "solitary.db"

def reset_database():
    print(f"Checking for existing database file: {DB_FILE}")
    if os.path.exists(DB_FILE):
        print(f"Deleting {DB_FILE}...")
        try:
            os.remove(DB_FILE)
            print("Database file deleted successfully.")
        except Exception as e:
            print(f"Error deleting database file: {e}")
            return
    else:
        print("Database file does not exist.")

    print("Creating new database tables...")
    try:
        # 确保所有模型都被导入，这样create_all才能看到它们
        # User, HikingRecord, Message, Feedback, Friendship 已经被导入
        database.Base.metadata.create_all(bind=database.engine)
        print("Database tables created successfully!")
        print("All tables (users, hiking_records, messages, feedbacks, friendships) created.")
    except Exception as e:
        print(f"Error creating tables: {e}")

if __name__ == "__main__":
    reset_database()
