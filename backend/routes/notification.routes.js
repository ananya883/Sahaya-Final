import express from "express";
import Notification from "../models/Notification.js";

const router = express.Router();

// -----------------------------
// Get notifications for admin
// -----------------------------
router.get("/admin", async (req, res) => {
  try {
    const notifications = await Notification.find({
      targetRole: "admin",
    })
      .populate({
        path: 'relatedMissingPerson',
        populate: { path: 'registeredBy', select: 'Name mobile email' }
      })
      .populate({
        path: 'relatedUnknownPerson',
        populate: { path: 'reportedBy', select: 'managerName contactNumber email campName' }
      })
      .populate('relatedMatch')
      .sort({ createdAt: -1 });

    res.json(notifications);
  } catch (err) {
    console.error("❌ Fetch admin notifications error:", err);
    res.status(500).json({ error: err.message });
  }
});

// -----------------------------
// Get notifications for camp manager
// -----------------------------
router.get("/camp/:campId", async (req, res) => {
  try {
    const notifications = await Notification.find({
      targetRole: "camp_manager",
      targetCampId: req.params.campId,
    })
      .populate({
        path: 'relatedMissingPerson',
        populate: { path: 'registeredBy', select: 'Name mobile email' }
      })
      .populate({
        path: 'relatedUnknownPerson',
        populate: { path: 'reportedBy', select: 'managerName contactNumber email campName' }
      })
      .populate('relatedMatch')
      .sort({ createdAt: -1 });

    res.json(notifications);
  } catch (err) {
    console.error("❌ Fetch camp notifications error:", err);
    res.status(500).json({ error: err.message });
  }
});

// -----------------------------
// Get notifications for a user
// -----------------------------
router.get("/user/:userId", async (req, res) => {
  try {
    const notifications = await Notification.find({
      userId: req.params.userId,
    })
      .populate({
        path: 'relatedMissingPerson',
        populate: { path: 'registeredBy', select: 'Name mobile email' }
      })
      .populate({
        path: 'relatedUnknownPerson',
        populate: { path: 'reportedBy', select: 'managerName contactNumber email campName' }
      })
      .populate('relatedMatch')
      .sort({ createdAt: -1 });

    // Debug logging
    if (notifications.length > 0) {
      console.log("📢 Total notifications found:", notifications.length);
      console.log("📢 First notification ID:", notifications[0]._id);
      console.log("📢 First notification full data:", JSON.stringify(notifications[0], null, 2));

      // Check if populate worked
      const missing = notifications[0].relatedMissingPerson;
      const unknown = notifications[0].relatedUnknownPerson;

      console.log("📢 Missing person exists:", !!missing);
      if (missing) {
        console.log("📢 Missing person ID:", missing._id);
        console.log("📢 Missing person name:", missing.name);
        console.log("📢 Missing person registeredBy:", missing.registeredBy);
        console.log("📢 Missing person registeredBy type:", typeof missing.registeredBy);
      }

      console.log("📢 Unknown person exists:", !!unknown);
      if (unknown) {
        console.log("📢 Unknown person ID:", unknown._id);
        console.log("📢 Unknown person reportedBy:", unknown.reportedBy);
        console.log("📢 Unknown person reportedBy type:", typeof unknown.reportedBy);
      }
    }

    res.json(notifications);
  } catch (err) {
    console.error("❌ Fetch notifications error:", err);
    res.status(500).json({ error: err.message });
  }
});

// -----------------------------
// Mark notification as read
// -----------------------------
router.post("/mark-read/:id", async (req, res) => {
  try {
    const notification = await Notification.findByIdAndUpdate(
      req.params.id,
      { isRead: true },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }

    res.json({ message: "Notification marked as read" });
  } catch (err) {
    console.error("❌ Mark-read error:", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
