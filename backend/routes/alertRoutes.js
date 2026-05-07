import express from "express";
import User from "../models/users.js";

const router = express.Router();

// Pre-defined known locations library
const KNOWN_LOCATIONS = [
  "Vannappuram",
  "Adimali",
  "Cheruthoni",
  "Kokkayar",
  "Sulthan Bathery",
  "Meppadi",
  "Kalpetta",
  "Munnar",
  "Vythiri",
  "Mananthavady"
];

// --------------------------------------------------
// 1. Get available locations
// --------------------------------------------------
router.get("/locations", (req, res) => {
  try {
    return res.status(200).json({ locations: KNOWN_LOCATIONS });
  } catch (err) {
    return res.status(500).json({ error: "Server error" });
  }
});

// --------------------------------------------------
// 2. Subscribe to locations
// --------------------------------------------------
router.post("/subscribe", async (req, res) => {
  try {
    const { userId, locations } = req.body;

    if (!userId) {
      return res.status(400).json({ error: "User ID is required" });
    }

    if (!Array.isArray(locations)) {
      return res.status(400).json({ error: "Locations must be an array" });
    }

    const validLocations = locations.filter(loc => KNOWN_LOCATIONS.includes(loc));

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    user.subscribedLocations = validLocations;
    await user.save();

    return res.status(200).json({
      message: "Subscription updated successfully",
      subscribedLocations: user.subscribedLocations
    });
  } catch (err) {
    console.error("Error updating subscriptions: ", err);
    return res.status(500).json({ error: "Server error" });
  }
});

// --------------------------------------------------
// 3. Fetch user's active alerts (calls Flask API)
// --------------------------------------------------
router.get("/my-alerts", async (req, res) => {
  try {
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({ error: "User ID is required" });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    const locations = user.subscribedLocations || [];

    if (locations.length === 0) {
      return res.status(200).json({ alerts: [] });
    }

    // Call Flask AI Service
    // Use env variable or fallback to localhost (if running without Docker)
    const AI_URL = process.env.AI_SERVICE_URL || "http://127.0.0.1:5002";
    
    const flaskResponse = await fetch(`${AI_URL}/predict-alerts`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ locations })
    });

    if (!flaskResponse.ok) {
      throw new Error(`Flask API returned status: ${flaskResponse.status}`);
    }

    const flaskData = await flaskResponse.json();
    const allAlerts = flaskData.alerts || [];

    // Remove the filter to send ALL locations (even safe ones) so the frontend can display weather details.
    return res.status(200).json({ alerts: allAlerts });
  } catch (err) {
    console.error("Error fetching alerts from AI service: ", err);
    return res.status(500).json({ error: "Server error fetching alerts" });
  }
});

// --------------------------------------------------
// 4. Fetch user's subscriptions
// --------------------------------------------------
router.get("/my-subscriptions", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "User ID is required" });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: "User not found" });

    res.status(200).json({ subscribedLocations: user.subscribedLocations || [] });
  } catch (err) {
    res.status(500).json({ error: "Server error" });
  }
});


export default router;
