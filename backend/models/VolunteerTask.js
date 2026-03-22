import mongoose from "mongoose";

const volunteerTaskSchema = new mongoose.Schema({
  sosId: { type: mongoose.Schema.Types.ObjectId, ref: 'SOS', required: true },
  volunteerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  status: { type: String, enum: ['pending', 'in progress', 'resolved'], default: 'pending' },
  acceptedAt: { type: Date },
  resolvedAt: { type: Date }
}, { timestamps: true });

export default mongoose.model("VolunteerTask", volunteerTaskSchema);
