import mongoose from 'mongoose';

mongoose.connect('mongodb://127.0.0.1:27017/sahaya').then(async () => {
    const db = mongoose.connection.db;
    const collections = await db.listCollections().toArray();
    console.log("Collections:", collections.map(c => c.name));
    
    // The collection name is usually lowercased plural of the model name "PublicNotice" -> publicnotices
    const notices = await db.collection('publicnotices').find().toArray();
    console.log("Notices:", notices);
    
    process.exit(0);
}).catch(err => {
    console.error(err);
    process.exit(1);
});
