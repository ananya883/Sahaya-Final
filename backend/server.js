import express from "express";
import mongoose from "mongoose";
import cors from "cors";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

import authRoutes from "./routes/authRoutes.js";
import sosRoutes from "./routes/sosRoutes.js";
import missingPersonRoutes from "./routes/missingPersonRoutes.js";
import matchRoutes from "./routes/match.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import unknownRoutes from "./routes/unknown.routes.js";
import campRoutes from "./routes/campRoutes.js";
import adminRoutes from "./routes/adminRoutes.js";
import publicNoticeRoutes from "./routes/publicNoticeRoutes.js";
import campManagerAuthRoutes from "./routes/campManagerAuthRoutes.js";
import campManagerRoutes from "./routes/campManagerRoutes.js";
import dashboardRoutes from "./routes/dashboardRoutes.js";
import donorRoutes from "./routes/donorRoutes.js";
import inmateRoutes from "./routes/inmateRoutes.js";
import inventoryRoutes from "./routes/inventoryRoutes.js";
import alertRoutes from "./routes/alertRoutes.js";
import volunteerRoutes from "./routes/volunteerRoutes.js";

dotenv.config();

const app = express();

// ---------- Middleware ----------
app.use(cors());
app.use(express.json());

// Global Request Logger
app.use((req, res, next) => {
  console.log(`🔔 [INCOMING] ${req.method} ${req.url}`);
  next();
});

app.use("/api/unknown", unknownRoutes);


// ---------- File path setup ----------
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ---------- Serve uploaded images ----------
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ---------- Test route ----------
app.get("/", (req, res) => {
  res.send("Server is running!");
});

// ---------- Routes ----------
app.use("/api/auth", authRoutes);
app.use("/api/sos", sosRoutes);

// Missing person (register, list, etc.)
app.use("/api/missing", missingPersonRoutes);

// Matching (found person → AI → match)
app.use("/api/match", matchRoutes);

// Notifications
app.use("/api/notifications", notificationRoutes);
app.use("/api/public-notices", publicNoticeRoutes);

// Camps
app.use("/api/camps", campRoutes);

// Admin (create camps, register disasters)
app.use("/api/admin", adminRoutes);

// Camp Manager Auth
app.use("/api/campmanager/auth", campManagerAuthRoutes);

// Camp Manager Operations
app.use("/api/campmanager", campManagerRoutes);

// Dashboard
app.use("/api/dashboard", dashboardRoutes);

// Donor Operations
app.use("/api/donor", donorRoutes);

// Inmates
app.use("/api/inmates", inmateRoutes);

// Inventory
app.use("/api/inventory", inventoryRoutes);

// Early Warning Alerts
app.use("/api/alerts", alertRoutes);
// Volunteer 
app.use("/api/volunteer", volunteerRoutes);

// ---------- DB & Server ----------
const PORT = process.env.PORT || 5000;

mongoose
  .connect(process.env.MONGO_URI, { dbName: "sahaya" })
  .then(() => {
    console.log("✅ MongoDB connected");
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`🚀 Server running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err.message);
  });



