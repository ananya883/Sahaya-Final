import express from 'express';
import User from '../models/users.js';
import SOS from '../models/sos.js';
import VolunteerTask from '../models/VolunteerTask.js';

const router = express.Router();

// Get all SOS requests with their volunteer tasks
router.get('/sos', async (req, res) => {
    try {
        const sosList = await SOS.find()
            .sort({ timestamp: -1 })
            .populate('requestedBy', 'Name mobile email');
        const tasks = await VolunteerTask.find().populate('volunteerId', 'Name mobile email');

        // Merge tasks into SOS
        const result = sosList.map(sos => {
            const task = tasks.find(t => t.sosId.toString() === sos._id.toString());
            
            const timeDiffHours = (new Date() - new Date(sos.timestamp)) / (1000 * 60 * 60);
            let isExpired = false;
            if (sos.isManualExpired) isExpired = true;
            else if (sos.isManualUnexpired) isExpired = false;
            else if (timeDiffHours >= 36) isExpired = true;

            let finalStatus = 'pending';
            if (task) {
                finalStatus = task.status;
            } else if (isExpired) {
                finalStatus = 'expired';
            }

            return {
                ...sos.toObject(),
                task: task || null,
                status: finalStatus,
                volunteer: task && task.volunteerId ? task.volunteerId : null
            };
        });

        res.json(result);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Accept an SOS request
router.post('/sos/:id/accept', async (req, res) => {
    try {
        const { volunteerId } = req.body;
        const sosId = req.params.id;

        let task = await VolunteerTask.findOne({ sosId });
        if (task && task.status !== 'pending') {
            return res.status(400).json({ error: 'Already accepted or resolved' });
        }

        if (!task) {
            task = new VolunteerTask({ sosId, volunteerId, status: 'in progress', acceptedAt: new Date() });
        } else {
            task.volunteerId = volunteerId;
            task.status = 'in progress';
            task.acceptedAt = new Date();
        }
        await task.save();

        res.json(task);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Resolve an SOS request
router.post('/sos/:id/resolve', async (req, res) => {
    try {
        const sosId = req.params.id;
        const task = await VolunteerTask.findOne({ sosId, status: 'in progress' });

        if (!task) return res.status(404).json({ error: 'No active task found for this SOS' });

        task.status = 'resolved';
        task.resolvedAt = new Date();
        await task.save();

        res.json(task);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Upgrade user to volunteer
router.post('/upgrade', async (req, res) => {
    try {
        const { userId, skills, serviceLocation } = req.body;
        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ error: 'User not found' });

        if (!user.roles.includes('volunteer')) {
            user.roles.push('volunteer');
        }

        user.volunteerDetails = {
            ...user.volunteerDetails,
            skills: Array.isArray(skills) ? skills : (skills ? skills.split(',') : []),
            serviceLocation: serviceLocation,
        };

        await user.save();
        res.json({ message: 'Upgraded to volunteer successfully', user });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

export default router;
