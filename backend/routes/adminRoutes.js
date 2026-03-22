import express from "express";
import User from "../models/users.js";
import CampManager from "../models/CampManager.js";
import Disaster from "../models/Disaster.js";
import SOS from "../models/sos.js";
import DonationRecord from "../models/DonationRecord.js";
import MoneyDonation from "../models/MoneyDonation.js";
import { sendCampCredentials } from "../services/emailService.js";

const router = express.Router();

// Hardcoded admin credentials (for simplicity)
const ADMIN_USERNAME = "admin";
const ADMIN_PASSWORD = "admin123";

// Admin login
router.post("/login", async (req, res) => {
    try {
        const { username, password } = req.body;

        if (username === ADMIN_USERNAME && password === ADMIN_PASSWORD) {
            res.json({
                message: "Admin login successful",
                role: "admin",
                username: ADMIN_USERNAME,
            });
        } else {
            res.status(401).json({ message: "Invalid admin credentials" });
        }
    } catch (error) {
        console.error("Admin login error:", error);
        res.status(500).json({ message: "Login failed" });
    }
});

// Create new camp (admin only)
router.post("/create-camp", async (req, res) => {
    try {
        const { campName, managerName, email, password, location, contactNumber } = req.body;

        // Check if email already exists
        const existingManager = await CampManager.findOne({ email });
        if (existingManager) {
            return res.status(400).json({ message: "Email already registered" });
        }

        // Generate unique campId by finding the highest existing ID
        const lastCamp = await CampManager.findOne().sort({ campId: -1 }).limit(1);
        let nextId = 1;
        if (lastCamp && lastCamp.campId) {
            // Extract number from CAMP001, CAMP002, etc.
            const lastNumber = parseInt(lastCamp.campId.replace('CAMP', ''));
            nextId = lastNumber + 1;
        }
        const campId = `CAMP${String(nextId).padStart(3, "0")}`;

        // Create new camp manager
        const campManager = await CampManager.create({
            campId,
            campName,
            managerName,
            email,
            password,
            location,
            contactNumber,
        });

        // Send credentials email
        let emailSent = false;
        try {
            console.log(`📧 Attempting to send credentials email to: ${email}`);
            await sendCampCredentials({
                recipientEmail: email,
                campName,
                campId,
                managerName,
                password,
                location: location || "Not specified",
            });
            console.log(`✅ Credentials email sent successfully to ${email}`);
            emailSent = true;
        } catch (emailError) {
            console.error("⚠️ Camp created but email failed:");
            console.error("Error details:", emailError.message);
            console.error("Full error:", emailError);
            emailSent = false;
            // Continue even if email fails - admin can manually share credentials
        }

        res.status(201).json({
            message: emailSent
                ? "Camp created successfully and credentials sent via email"
                : "Camp created successfully but email failed",
            campId: campManager.campId,
            campName: campManager.campName,
            email: campManager.email,
            password: password, // Return password so admin can share if email fails
            emailSent: emailSent,
        });
    } catch (error) {
        console.error("Create camp error:", error);
        res.status(500).json({ message: "Failed to create camp", error: error.message });
    }
});

// Get all camps (admin only)
router.get("/camps", async (req, res) => {
    try {
        const camps = await CampManager.find().sort({ createdAt: -1 });

        const campList = camps.map(camp => ({
            campId: camp.campId,
            campName: camp.campName,
            managerName: camp.managerName,
            email: camp.email,
            location: camp.location,
            contactNumber: camp.contactNumber,
            createdAt: camp.createdAt,
        }));

        res.json(campList);
    } catch (error) {
        console.error("Fetch camps error:", error);
        res.status(500).json({ message: "Failed to fetch camps" });
    }
});

// Get all users (admin only)
router.get("/users", async (req, res) => {
    try {
        const users = await User.find().select("-password").sort({ createdAt: -1 });
        res.json(users);
    } catch (error) {
        console.error("Fetch users error:", error);
        res.status(500).json({ message: "Failed to fetch users" });
    }
});

// Delete camp (admin only)
router.delete("/camp/:campId", async (req, res) => {
    try {
        const { campId } = req.params;

        const result = await CampManager.deleteOne({ campId });

        if (result.deletedCount === 0) {
            return res.status(404).json({ message: "Camp not found" });
        }

        res.json({ message: "Camp deleted successfully" });
    } catch (error) {
        console.error("Delete camp error:", error);
        res.status(500).json({ message: "Failed to delete camp" });
    }
});

// Register new disaster (admin only)
router.post("/register-disaster", async (req, res) => {
    try {
        const {
            disasterName,
            location,
            dateOccurred,
            disasterType,
            severity,
            description,
            affectedPopulation,
        } = req.body;

        // Validate required fields
        if (!disasterName || !location || !dateOccurred || !disasterType || !severity) {
            return res.status(400).json({
                message: "Missing required fields: disasterName, location, dateOccurred, disasterType, severity"
            });
        }

        // Generate unique disasterId
        const lastDisaster = await Disaster.findOne().sort({ disasterId: -1 }).limit(1);
        let nextId = 1;
        if (lastDisaster && lastDisaster.disasterId) {
            const lastNumber = parseInt(lastDisaster.disasterId.replace('DIS', ''));
            nextId = lastNumber + 1;
        }
        const disasterId = `DIS${String(nextId).padStart(3, "0")}`;

        // Create new disaster record
        const disaster = await Disaster.create({
            disasterId,
            disasterName,
            location,
            dateOccurred: new Date(dateOccurred),
            disasterType,
            severity,
            description: description || "",
            affectedPopulation: affectedPopulation || 0,
            status: "Active",
        });

        res.status(201).json({
            message: "Disaster registered successfully",
            disaster: {
                disasterId: disaster.disasterId,
                disasterName: disaster.disasterName,
                location: disaster.location,
                dateOccurred: disaster.dateOccurred,
                disasterType: disaster.disasterType,
                severity: disaster.severity,
                status: disaster.status,
            },
        });
    } catch (error) {
        console.error("Register disaster error:", error);
        res.status(500).json({ message: "Failed to register disaster", error: error.message });
    }
});

// Get all disasters (admin only)
router.get("/disasters", async (req, res) => {
    try {
        const disasters = await Disaster.find().sort({ dateOccurred: -1 });

        const disasterList = disasters.map(disaster => ({
            disasterId: disaster.disasterId,
            disasterName: disaster.disasterName,
            location: disaster.location,
            dateOccurred: disaster.dateOccurred,
            disasterType: disaster.disasterType,
            severity: disaster.severity,
            description: disaster.description,
            affectedPopulation: disaster.affectedPopulation,
            status: disaster.status,
            createdAt: disaster.createdAt,
        }));

        res.json(disasterList);
    } catch (error) {
        console.error("Fetch disasters error:", error);
        res.status(500).json({ message: "Failed to fetch disasters" });
    }
});

// Get specific disaster details (admin only)
router.get("/disaster/:disasterId", async (req, res) => {
    try {
        const { disasterId } = req.params;
        const disaster = await Disaster.findOne({ disasterId });

        if (!disaster) {
            return res.status(404).json({ message: "Disaster not found" });
        }

        res.json({
            disasterId: disaster.disasterId,
            disasterName: disaster.disasterName,
            location: disaster.location,
            dateOccurred: disaster.dateOccurred,
            disasterType: disaster.disasterType,
            severity: disaster.severity,
            description: disaster.description,
            affectedPopulation: disaster.affectedPopulation,
            status: disaster.status,
            createdAt: disaster.createdAt,
            updatedAt: disaster.updatedAt,
        });
    } catch (error) {
        console.error("Fetch disaster error:", error);
        res.status(500).json({ message: "Failed to fetch disaster details" });
    }
});

// Update disaster (admin only)
router.put("/disaster/:disasterId", async (req, res) => {
    try {
        const { disasterId } = req.params;
        const updateData = req.body;

        // Don't allow updating disasterId
        delete updateData.disasterId;

        const disaster = await Disaster.findOneAndUpdate(
            { disasterId },
            updateData,
            { new: true, runValidators: true }
        );

        if (!disaster) {
            return res.status(404).json({ message: "Disaster not found" });
        }

        res.json({
            message: "Disaster updated successfully",
            disaster: {
                disasterId: disaster.disasterId,
                disasterName: disaster.disasterName,
                location: disaster.location,
                dateOccurred: disaster.dateOccurred,
                disasterType: disaster.disasterType,
                severity: disaster.severity,
                description: disaster.description,
                affectedPopulation: disaster.affectedPopulation,
                status: disaster.status,
            },
        });
    } catch (error) {
        console.error("Update disaster error:", error);
        res.status(500).json({ message: "Failed to update disaster", error: error.message });
    }
});

// Delete disaster (admin only)
router.delete("/disaster/:disasterId", async (req, res) => {
    try {
        const { disasterId } = req.params;

        const result = await Disaster.deleteOne({ disasterId });

        if (result.deletedCount === 0) {
            return res.status(404).json({ message: "Disaster not found" });
        }

        res.json({ message: "Disaster deleted successfully" });
    } catch (error) {
        console.error("Delete disaster error:", error);
        res.status(500).json({ message: "Failed to delete disaster" });
    }
});

// Mark SOS as expired manually (admin only)
router.post("/sos/:id/expire", async (req, res) => {
    try {
        const { id } = req.params;
        const sos = await SOS.findById(id);
        if (!sos) return res.status(404).json({ message: "SOS not found" });

        sos.isManualExpired = true;
        sos.isManualUnexpired = false;
        await sos.save();

        res.json({ message: "SOS marked as expired", sos });
    } catch (error) {
        console.error("SOS expiration error:", error);
        res.status(500).json({ message: "Failed to mark SOS as expired" });
    }
});

// Undo SOS expiration manually (admin only)
router.post("/sos/:id/unexpire", async (req, res) => {
    try {
        const { id } = req.params;
        const sos = await SOS.findById(id);
        if (!sos) return res.status(404).json({ message: "SOS not found" });

        sos.isManualExpired = false;
        sos.isManualUnexpired = true;
        await sos.save();

        res.json({ message: "SOS expiration undone", sos });
    } catch (error) {
        console.error("SOS unexpiration error:", error);
        res.status(500).json({ message: "Failed to undo SOS expiration" });
    }
});

// ─────────────────────────────────────────
// ADMIN DONATION REPORTS
// ─────────────────────────────────────────

// GET /api/admin/reports/inventory-donations
router.get("/reports/inventory-donations", async (req, res) => {
  try {
    const records = await DonationRecord.find().sort({ donatedAt: -1 });

    const result = await Promise.all(records.map(async (r) => {
      // Resolve camp name
      let campName = r.campId || "Unknown";
      if (r.campId) {
        const camp = await CampManager.findOne({ campId: r.campId });
        if (camp) campName = camp.campName;
      }

      // Resolve donor mobile by matching name in Users
      let donorMobile = "N/A";
      let donorEmail = "N/A";
      if (r.donorName && r.donorName !== "Anonymous Donor" && r.donorName !== "Anonymous") {
        const user = await User.findOne({ Name: new RegExp("^" + r.donorName + "$", "i") });
        if (user) {
          donorMobile = user.mobile || "N/A";
          donorEmail = user.email || "N/A";
        }
      }

      return {
        _id: r._id,
        donorName: r.donorName || "Anonymous",
        donorMobile,
        donorEmail,
        campName,
        itemName: r.itemName,
        quantity: r.quantity,
        unit: r.unit,
        status: r.status,
        donatedAt: r.donatedAt,
        receivedAt: r.receivedAt || null,
      };
    }));

    res.json(result);
  } catch (err) {
    console.error("Inventory donations report error:", err);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/reports/money-donations
router.get("/reports/money-donations", async (req, res) => {
  try {
    const records = await MoneyDonation.find().sort({ donatedAt: -1 });

    const result = await Promise.all(records.map(async (r) => {
      // Resolve camp name
      let campName = r.campId || "General";
      if (r.campId && r.campId !== "General") {
        const camp = await CampManager.findOne({ campId: r.campId });
        if (camp) campName = camp.campName;
      }

      // Resolve donor name + mobile from User by _id (donorId)
      let donorName = r.donorId || "Anonymous";
      let donorMobile = "N/A";
      let donorEmail = "N/A";
      if (r.donorId && r.donorId !== "Anonymous") {
        try {
          const user = await User.findById(r.donorId);
          if (user) {
            donorName = user.Name || donorName;
            donorMobile = user.mobile || "N/A";
            donorEmail = user.email || "N/A";
          }
        } catch (_) { /* donorId may not be a valid ObjectId */ }
      }

      return {
        _id: r._id,
        donorName,
        donorMobile,
        donorEmail,
        campName,
        amount: r.amount,
        paymentStatus: r.paymentStatus,
        donatedAt: r.donatedAt,
      };
    }));

    res.json(result);
  } catch (err) {
    console.error("Money donations report error:", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
