from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017/")
db = client["sahaya"]

notifications = list(db.notifications.find().sort("createdAt", -1).limit(1))

for n in notifications:
    print(n)
