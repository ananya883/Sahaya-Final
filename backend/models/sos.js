import mongoose from "mongoose";

const sosSchema = new mongoose.Schema({
  emergency_type: { type: String, required: true },
  disaster_type:  { type: String, default: '' },
  latitude:       { type: Number },
  longitude:      { type: Number },
  timestamp:      { type: Date, default: Date.now },
  image_url:      { type: String, default: '' },
  requestedBy:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  isManualExpired: { type: Boolean, default: false },
  isManualUnexpired: { type: Boolean, default: false }
});

export default mongoose.model("SOS", sosSchema);
