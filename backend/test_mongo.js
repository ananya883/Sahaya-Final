import mongoose from "mongoose";
import dotenv from "dotenv";
import Notification from "./models/Notification.js";
import Match from "./models/Match.js";
import MissingPerson from "./models/MissingPerson.js";
import UnknownPerson from "./models/UnknownPerson.js";
import User from "./models/users.js";

dotenv.config();

async function run() {
  await mongoose.connect(process.env.MONGO_URI, { dbName: "sahaya" });
  const notifications = await Notification.find({ type: "match" }).sort({ createdAt: -1 }).limit(1)
    .populate('relatedMatch relatedMissingPerson relatedUnknownPerson').lean();
  console.log("Notif:");
  console.log(JSON.stringify(notifications, null, 2));

  // let's also fetch the Match
  if (notifications[0] && notifications[0].relatedMatch) {
     const match = await Match.findById(notifications[0].relatedMatch._id).lean();
     console.log("Match Doc:", JSON.stringify(match, null, 2));
  }
  process.exit(0);
}

run();
