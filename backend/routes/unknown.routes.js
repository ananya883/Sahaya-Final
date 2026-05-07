import express from "express";
import multer from "multer";
import path from "path";
import axios from "axios";
import fs from "fs";
import FormData from "form-data";

import MissingPerson from "../models/MissingPerson.js";
import UnknownPerson from "../models/UnknownPerson.js";
import Match from "../models/Match.js";
import Notification from "../models/Notification.js";
import CampManager from "../models/CampManager.js";

const router = express.Router();

// Store unknown images
const storage = multer.diskStorage({
  destination: "uploads/unknown",
  filename: (req, file, cb) => {
    cb(null, Date.now() + "-" + file.originalname);
  },
});
const upload = multer({ storage });

const AI_BASE_URL = "http://127.0.0.1:5002";

const MATCH_THRESHOLD = 0.85;

// -----------------------------------
// UPLOAD UNKNOWN PERSON (FOUND PERSON)
// -----------------------------------
router.post("/upload", upload.single("photo"), async (req, res) => {
  try {
    console.log("🧍 Unknown person upload hit");

    const {
      campId,
      gender,
      age,
      height,
      weight,
      foundLocation,
      foundDate,
    } = req.body;

    if (!campId) {
      return res.status(400).json({ message: "campId is required" });
    }

    const campManager = await CampManager.findOne({ campId });
    if (!campManager) {
      return res.status(404).json({ message: "Camp manager not found" });
    }

    if (!req.file) {
      return res.status(400).json({ message: "Photo required" });
    }

    const imagePath = path.resolve(req.file.path);

    let embedding = null;
    try {
      // 1️⃣ Send REAL IMAGE FILE to AI service
      const formData = new FormData();
      formData.append("image", fs.createReadStream(imagePath));

      const extractRes = await axios.post(
        `${AI_BASE_URL}/extract`,
        formData,
        { headers: formData.getHeaders(), timeout: 10000 }
      );

      if (extractRes.data && extractRes.data.embedding) {
        embedding = extractRes.data.embedding;
      }
    } catch (aiError) {
      console.warn("⚠️ AI Service unavailable/failed, skipping embedding:", aiError.message);
    }

    if (!embedding || !Array.isArray(embedding)) {
      // Optionally continue without embedding or fail. Here we continue.
      // return res.status(500).json({ message: "Embedding extraction failed" }); 
      console.log("⚠️ Continuing without embedding.");
    }

    // 2️⃣ Save unknown person FIRST
    const unknown = await UnknownPerson.create({
      imagePath: req.file.path,
      faceEmbedding: embedding,
      reportedBy: campManager._id,
      status: "unknown",
      gender,
      age: age ? Number(age) : undefined,
      height,
      weight,
      foundLocation,
      foundDate,
    });

    console.log("✅ Unknown saved:", unknown._id.toString());

    // 3️⃣ Respond IMMEDIATELY
    res.status(201).json({
      message: "Unknown person saved. Matching running in background.",
      unknownPersonId: unknown._id,
    });

    // 4️⃣ Run matching in BACKGROUND (do not await)
    if (embedding) {
      runMatchingInBackground(unknown, embedding).catch(err =>
        console.error("❌ Background matching error:", err)
      );
    }

  } catch (err) {
    console.error("❌ Unknown upload error:", err);
    res.status(500).json({ error: err.message });
  }
});

// Async function for background matching
async function runMatchingInBackground(unknown, embedding) {
  try {
    console.log("🔍 Background matching started for unknown person:", unknown._id.toString());
    if (!embedding || !Array.isArray(embedding)) {
      console.log("⚠️ Unknown embedding is invalid or missing, skipping matching");
      return;
    }
    
    const missingPeople = await MissingPerson.find({
      status: { $in: ["missing", "active"] },
    });

    console.log("📊 Found", missingPeople.length, "missing people to match against");

    for (const person of missingPeople) {
      if (!person.faceEmbedding) {
        console.log("  ⚠️ Missing person", person._id.toString(), "has no embedding, skipping");
        continue;
      }

      const matchRes = await axios.post(
        `${AI_BASE_URL}/match`,
        {
          embedding1: person.faceEmbedding,
          embedding2: embedding,
        },
        { timeout: 20000 }
      );

      const similarity = matchRes.data.similarity;
      console.log(`  📈 Match score with ${person._id.toString()}: ${(similarity * 100).toFixed(2)}%`);

      if (similarity >= MATCH_THRESHOLD) {
        console.log(`  ✅ MATCH FOUND! Score ${(similarity * 100).toFixed(2)}% >= ${MATCH_THRESHOLD * 100}%`);
        // Determine confidence level
        let confidence = "low";
        if (similarity >= 0.95) confidence = "high";
        else if (similarity >= 0.85) confidence = "medium";

        // Store match record
        const matchRecord = await Match.create({
          missingPerson: person._id,
          unknownPerson: unknown._id,
          similarity,
          confidenceLevel: confidence,
          status: "pending",
        });

        // Update missing person status to "found"
        await MissingPerson.findByIdAndUpdate(person._id, {
          status: "found",
          matchedUnknown: unknown._id,
        });

        // Update unknown person status to "identified"
        await UnknownPerson.findByIdAndUpdate(unknown._id, {
          status: "identified",
          matchedMissing: person._id,
        });

        // Notify missing person reporter (show unknown person reporter's contact)
        if (person.registeredBy) {
          console.log("📬 Creating notification for missing person reporter:", person.registeredBy.toString());
          await Notification.create({
            userId: person.registeredBy,
            targetRole: "user",
            type: "match",
            title: "Possible Match Found",
            message: `A person matching ${person.name} was found (${(similarity * 100).toFixed(2)}% similarity). Please verify.`,
            relatedMissingPerson: person._id,
            relatedUnknownPerson: unknown._id,
            relatedMatch: matchRecord._id,
          });
          console.log("✅ Notification created for user:", person.registeredBy.toString());
        } else {
          console.warn("⚠️ Missing person has no registeredBy ID");
        }

        // Notify unknown person reporter (Camp Manager)
        if (unknown.reportedBy) {
          console.log("📬 Unknown.reportedBy exists:", unknown.reportedBy.toString());
          const campManager = await CampManager.findById(unknown.reportedBy);
          if (campManager) {
            console.log("📬 Found camp manager with campId:", campManager.campId);
            await Notification.create({
              targetRole: "camp_manager",
              targetCampId: campManager.campId,
              type: "match",
              title: "Match Found for Unknown Person",
              message: `The unknown person you reported matches ${person.name} (${(similarity * 100).toFixed(2)}% similarity). Please verify.`,
              relatedMissingPerson: person._id,
              relatedUnknownPerson: unknown._id,
              relatedMatch: matchRecord._id,
            });
            console.log("✅ Notification created for camp manager:", campManager.campId);
          } else {
            console.warn("⚠️ Camp manager not found for reportedBy ID:", unknown.reportedBy.toString());
          }
        } else {
          console.warn("⚠️ Unknown person has no reportedBy ID");
        }

        // Notify Admin
        await Notification.create({
          targetRole: "admin",
          type: "match",
          title: "System: Match Found",
          message: `A match was found between ${person.name} and an unknown person (${(similarity * 100).toFixed(2)}% similarity).`,
          relatedMissingPerson: person._id,
          relatedUnknownPerson: unknown._id,
          relatedMatch: matchRecord._id,
        });
      }
    }
  } catch (error) {
    console.error(`⚠️ Error in background matching for ${unknown._id}:`, error.message);
  }
}

export default router;
