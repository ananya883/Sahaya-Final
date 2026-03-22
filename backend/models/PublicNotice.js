import mongoose from "mongoose";

const publicNoticeSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      required: true,
    },
    fileUrl: {
      type: String,
    },
    fileName: {
      type: String, // Original name of the uploaded file
    },
    postedBy: {
      type: String,
      default: "Admin",
    },
  },
  { timestamps: true }
);

export default mongoose.model("PublicNotice", publicNoticeSchema);
