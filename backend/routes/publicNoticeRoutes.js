import express from "express";
import multer from "multer";
import path from "path";
import PublicNotice from "../models/PublicNotice.js";

const router = express.Router();

// ---------- Multer Configuration ----------
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/");
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + "-" + Math.round(Math.random() * 1e9) + path.extname(file.originalname));
  },
});
const upload = multer({ storage });

// -----------------------------
// POST: Create a new Public Notice (Admin)
// -----------------------------
router.post("/", upload.single("file"), async (req, res) => {
  try {
    const { title, message } = req.body;
    
    if (!title || !message) {
      return res.status(400).json({ error: "Title and message are required." });
    }

    const fileUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const fileName = req.file ? req.file.originalname : null;

    const newNotice = new PublicNotice({
      title,
      message,
      fileUrl,
      fileName,
    });

    await newNotice.save();
    console.log("📢 [PublicNotice] New broadcast created:", newNotice._id);

    res.status(201).json({ message: "Notice broadcasted successfully", notice: newNotice });
  } catch (err) {
    console.error("❌ Create Public Notice Error:", err);
    res.status(500).json({ error: err.message });
  }
});

// -----------------------------
// GET: Fetch all Public Notices
// -----------------------------
router.get("/", async (req, res) => {
  try {
    const notices = await PublicNotice.find().sort({ createdAt: -1 });
    res.status(200).json(notices);
  } catch (err) {
    console.error("❌ Fetch Public Notices Error:", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
