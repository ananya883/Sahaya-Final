import mongoose from "mongoose";

const UnknownPersonSchema = new mongoose.Schema(
  {
    imagePath: {
      type: String,
      required: true,
    },

    gender: String,
    age: Number,
    height: String,
    weight: String,
    foundLocation: String,
    foundDate: Date,

    faceEmbedding: {
      type: [Number],
      required: false, // Changed to false to prevent save failure on AI timeout
    },

    reportedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "CampManager",
      required: true,
    },

    status: {
      type: String,
      enum: ["unknown", "identified"],
      default: "unknown",
    },

    matchedMissing: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MissingPerson",
      default: null,
    },
  },
  { timestamps: true }
);

export default mongoose.model("UnknownPerson", UnknownPersonSchema);
