import express from "express";
import CampRequest from "../models/CampRequest.js";
import MoneyDonation from "../models/MoneyDonation.js";
import DonationRecord from "../models/DonationRecord.js";
import crypto from "crypto";
import Razorpay from "razorpay";

const router = express.Router();

// Donate items
router.post("/donate-item", async (req, res) => {
  try {
    const { requestId, donateQty, donorName } = req.body;

    const request = await CampRequest.findById(requestId);
    if (!request || request.remainingQty <= 0) {
      return res.status(400).json({ message: "Invalid or fulfilled request" });
    }

    // Validate donation amount
    if (donateQty > request.remainingQty) {
      return res.status(400).json({
        message: `Cannot donate more than remaining quantity (${request.remainingQty})`
      });
    }

    // 1. Deduct from Request (optimistically - shows donor it's being processed)
    request.remainingQty -= donateQty;

    if (request.remainingQty <= 0) {
      request.remainingQty = 0;
    }

    await request.save();

    // 2. Create Donation Record as PENDING
    // Camp manager will mark as Received/Not Received

    await DonationRecord.create({
      campId: request.campId,
      donorName: donorName || "Anonymous",
      itemName: request.itemName,
      quantity: donateQty,
      unit: request.unit || "units",
      status: "Pending" // Changed from "Received"
    });

    // NOTE: Inventory is NOT updated here anymore
    // It will be updated when camp manager clicks "Received" button

    res.json({
      message: "Donation recorded successfully. Awaiting camp confirmation.",
      remaining: request.remainingQty
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Donate money (MOCK - keeping for fallback/legacy if needed, but not used by new frontend)
router.post("/donate-money", async (req, res) => {
  try {
    const { donorId, campId, amount } = req.body;

    const donation = new MoneyDonation({
      donorId: donorId || "Anonymous",
      campId: campId || "General",
      amount: amount,
      paymentStatus: "SUCCESS" // Since UPI was launched, we assume success for this mock record
    });

    await donation.save();
    res.json({ message: "Money donation recorded successfully" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- NEW RAZORPAY INTEGRATION ---

// 1. Create Order
router.post("/create-razorpay-order", async (req, res) => {
  try {
    const { amount } = req.body;

    if (!amount) {
      return res.status(400).json({ error: "Amount is required" });
    }

    const instance = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID,
      key_secret: process.env.RAZORPAY_KEY_SECRET,
    });

    const options = {
      amount: amount * 100, // Razorpay works in paise (multiply by 100)
      currency: "INR",
      receipt: `receipt_${Date.now()}`,
    };

    const order = await instance.orders.create(options);
    if (!order) {
      return res.status(500).json({ error: "Some error occurred creating order" });
    }

    res.json(order);
  } catch (err) {
    console.error("Razorpay Order Error:", err);
    res.status(500).json({ error: err.message });
  }
});

// 2. Verify Payment & Save Record
router.post("/verify-razorpay-payment", async (req, res) => {
  try {
    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      donorId,
      campId,
      amount,
    } = req.body;

    // Verify signature
    const body = razorpay_order_id + "|" + razorpay_payment_id;
    const expectedSignature = crypto
      .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
      .update(body.toString())
      .digest("hex");

    const isAuthentic = expectedSignature === razorpay_signature;

    if (!isAuthentic) {
      // Payment Failed Verification
      const failedDonation = new MoneyDonation({
        donorId: donorId || "Anonymous",
        campId: campId || "General",
        amount: amount,
        paymentStatus: "FAILED",
      });
      await failedDonation.save();

      return res.status(400).json({ error: "Payment verification failed" });
    }

    // Payment Successful
    const dId = (donorId && donorId !== "null" && donorId !== "undefined") ? donorId : "Anonymous";
    const cId = (campId && campId !== "null" && campId !== "undefined") ? campId : "General";
    
    const donation = new MoneyDonation({
      donorId: dId,
      campId: cId,
      amount: amount,
      paymentStatus: "SUCCESS",
    });

    await donation.save();

    res.json({
      message: "Payment verified successfully",
      paymentId: razorpay_payment_id,
      donationRecord: donation
    });
  } catch (err) {
    console.error("Razorpay Verification Error:", err);
    res.status(500).json({ error: err.message });
  }
});

// 3. Get Donor History (Money & Items)
import CampManager from "../models/CampManager.js"; // Ensure we import CampManager

router.get("/history/:donorId/:donorName", async (req, res) => {
  try {
    const { donorId, donorName } = req.params;

    // Fetch Money Donations matching donorId
    const moneyDonationsRaw = await MoneyDonation.find({ donorId }).sort({ donatedAt: -1 });

    // Try to attach Camp details if possible
    const moneyDonations = await Promise.all(moneyDonationsRaw.map(async (record) => {
      let cName = record.campId;
      if (record.campId && record.campId !== "General") {
        const camp = await CampManager.findOne({ campId: record.campId });
        if (camp) cName = camp.campName;
      }
      return {
        _id: record._id,
        type: 'money',
        campId: cName, // Reusing campId variable in frontend to show the name
        amount: record.amount,
        status: record.paymentStatus,
        date: record.donatedAt
      };
    }));

    // Fetch Item Donations matching donorName (since DonationRecord uses donorName)
    // We do a case-insensitive regex match on donorName to be safe
    const itemDonationsRaw = await DonationRecord.find({
      donorName: { $regex: new RegExp("^" + donorName + "$", "i") }
    }).sort({ donatedAt: -1 });

    const itemDonations = await Promise.all(itemDonationsRaw.map(async (record) => {
      let cName = record.campId;
      if (record.campId && record.campId !== "General") {
        const camp = await CampManager.findOne({ campId: record.campId });
        if (camp) cName = camp.campName;
      }
      return {
        _id: record._id,
        type: 'item',
        campId: cName, // Reusing campId variable in frontend to show the name
        itemName: record.itemName,
        quantity: record.quantity,
        unit: record.unit,
        status: record.status, 
        date: record.donatedAt,
        receivedAt: record.receivedAt
      };
    }));

    res.json({
      moneyDonations,
      itemDonations,
      totalMoney: moneyDonations.filter(m => m.status === 'SUCCESS').reduce((acc, curr) => acc + curr.amount, 0),
      totalItems: itemDonations.length // Total count of distinct item donations
    });

  } catch (err) {
    console.error("Fetch Donor History Error:", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
