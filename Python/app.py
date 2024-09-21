import pyrebase

# Firebase Configuration
firebaseConfig = {
   "apiKey": "AIzaSyAMSzXMC54fFe-9_w12JZrhYDJHaySE2Rs",
  "authDomain": "segar-radios.firebaseapp.com",
  "databaseURL": "https://segar-radios-default-rtdb.firebaseio.com",
  "projectId": "segar-radios",
  "storageBucket": "segar-radios.appspot.com",
  "messagingSenderId": "628620288554",
  "appId": "1:628620288554:web:769a5c2e09c8a234df1953",
  "measurementId": "G-QZWD1Z8VVR"
}

# Initialize Firebase
firebase = pyrebase.initialize_app(firebaseConfig)
db = firebase.database()

# Firestore collection name
collection_name = "radio_stations"

def view_data():
    try:
        # Get all documents from Firestore
        docs = db.child(collection_name).get()

        print("\n--- Stored Radio Stations ---\n")
        if docs.each():
            for doc in docs.each():
                print(f"{doc.key()} => {doc.val()}")
        else:
            print("No data found.")
        print("\n---------------------------\n")
    except Exception as e:
        print(f"Error getting documents: {e}")

def insert_data():
    try:
        album_art_url = input("Enter Album Art URL: ")
        station_name = input("Enter Station Name: ")
        station_url = input("Enter Station URL: ")

        # Create data to insert
        station_data = {
            'album_art_url': album_art_url,
            'station_name': station_name,
            'station_url': station_url
        }

        # Add the data to Firestore
        db.child(collection_name).push(station_data)
        print("Data inserted successfully!\n")
    except Exception as e:
        print(f"Error inserting data: {e}")

def delete_data():
    try:
        doc_id = input("Enter document ID to delete: ")

        # Delete the document by its ID
        db.child(collection_name).child(doc_id).remove()
        print(f"Document {doc_id} deleted successfully!\n")
    except Exception as e:
        print(f"Error deleting document: {e}")

def main():
    while True:
        print("1. View Data")
        print("2. Insert Data")
        print("3. Delete Data")
        print("4. Exit")

        choice = input("Enter your choice (1-4): ")

        if choice == '1':
            view_data()
        elif choice == '2':
            insert_data()
        elif choice == '3':
            delete_data()
        elif choice == '4':
            print("Exiting program.")
            break
        else:
            print("Invalid choice. Please try again.\n")

if __name__ == "__main__":
    main()
