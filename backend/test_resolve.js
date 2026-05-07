import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

import VolunteerTask from './models/VolunteerTask.js';

async function checkTask() {
  await mongoose.connect(process.env.MONGO_URI, { dbName: 'sahaya' });
  const tasks = await VolunteerTask.find();
  console.log("Total tasks:", tasks.length);
  
  const resolvedTasks = tasks.filter(t => t.status === 'resolved');
  console.log("Total resolved tasks:", resolvedTasks.length);
  
  const tasksWithImage = tasks.filter(t => t.actionImage);
  console.log("Tasks with actionImage:", tasksWithImage.length);
  
  if (tasksWithImage.length > 0) {
    console.log("Sample tasks actionImage:", tasksWithImage.map(t => t.actionImage));
  }
  
  process.exit(0);
}

checkTask().catch(e => console.error(e));
