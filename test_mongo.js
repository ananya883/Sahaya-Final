const mongoose = require("mongoose");
const Notification = require("./backend/models/Notification.js").default;
const User = require("./backend/models/users.js").default;

async function run() {
  await mongoose.connect("mongodb://localhost:27017/sahaya");
  const notifications = await Notification.find().populate('relatedMatch relatedMissingPerson relatedUnknownPerson').lean();
  console.log(JSON.stringify(notifications, null, 2));
  process.exit(0);
}

run();
