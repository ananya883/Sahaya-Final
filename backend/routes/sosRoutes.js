// routes/sosRoutes.js
import express from "express";
import multer from "multer";
import path from "path";
import SOS from "../models/sos.js"; // Make sure SOS schema exists
import User from "../models/users.js";
import Notification from "../models/Notification.js";

const router = express.Router();

// ---------- Multer Configuration for Media Upload ----------
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/"); // Make sure this folder exists
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}${path.extname(file.originalname)}`);
  },
});

const upload = multer({ storage });

// ---------- POST /api/sos ----------
router.post("/", upload.single("image"), async (req, res) => {
  try {
    // Accept both camelCase (from Flutter) and snake_case field names
    const emergency_type = req.body.emergency_type || req.body.emergencyType;
    const disaster_type  = req.body.disaster_type  || req.body.disasterType || '';
    const { latitude, longitude, timestamp, userId } = req.body;

    if (!emergency_type) {
      return res.status(400).json({ success: false, message: "emergency_type is required" });
    }

    const image_url = req.file
      ? `${req.protocol}://${req.get("host")}/uploads/${req.file.filename}`
      : "";

    const newSos = new SOS({
      emergency_type,
      disaster_type,
      latitude:  latitude  ? parseFloat(latitude)  : null,
      longitude: longitude ? parseFloat(longitude) : null,
      timestamp: timestamp ? new Date(timestamp)   : new Date(),
      image_url,
      requestedBy: userId || null,
    });

    await newSos.save();

    // Send notification to all volunteers
    try {
      const volunteers = await User.find({ roles: "volunteer" });
      const notifications = volunteers.map(vol => ({
        userId: vol._id,
        type: "sos",
        title: "New SOS Alert",
        message: `An SOS alert for ${emergency_type} has been reported.`,
        priority: "high",
      }));
      if (notifications.length > 0) {
        await Notification.insertMany(notifications);
      }
    } catch (notifErr) {
      console.error("❌ Failed to send volunteer notifications:", notifErr);
    }

    res.status(201).json({
      success: true,
      message: "SOS stored successfully",
      sos: newSos,
    });
  } catch (err) {
    console.error("❌ SOS Save Error:", err);
    res.status(500).json({ success: false, message: "Server Error", error: err.message });
  }
});

// ---------- GET /api/sos ----------
router.get("/", async (req, res) => {
  try {
    const sosList = await SOS.find().sort({ timestamp: -1 });
    res.status(200).json(sosList);
  } catch (err) {
    console.error("❌ SOS Fetch Error:", err);
    res.status(500).json({ message: "Failed to fetch SOS reports", error: err.message });
  }
});

export default router;
