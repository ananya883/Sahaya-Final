import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: false,
      index: true,
    },

    targetRole: {
      type: String,
      enum: ["user", "camp_manager", "admin"],
      default: "user",
      index: true,
    },

    targetCampId: {
      type: String,
      required: false,
      index: true,
    },

    type: {
      type: String,
      enum: ["match", "sos", "system"],
      required: true,
    },

    title: {
      type: String,
      required: true,
    },

    message: {
      type: String,
      required: true,
    },

    relatedMissingPerson: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MissingPerson",
    },

    relatedUnknownPerson: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UnknownPerson",
    },

    relatedMatch: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Match",
    },

    priority: {
      type: String,
      enum: ["low", "normal", "high"],
      default: "normal",
    },

    pushSent: {
      type: Boolean,
      default: false,
    },

    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  { timestamps: true }
);

export default mongoose.model("Notification", notificationSchema);
