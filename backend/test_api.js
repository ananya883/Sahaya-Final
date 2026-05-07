import http from 'http';

http.get('http://localhost:5000/api/volunteer/sos', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const sosList = JSON.parse(data);
      console.log(`Fetched ${sosList.length} SOS requests.`);
      sosList.forEach(s => {
        console.log(`SOS ${s._id} | Status: ${s.status} | Task:`, s.task ? 'Yes' : 'No');
        if (s.task) {
           console.log(`   Task Status: ${s.task.status} | Action Image: ${s.task.actionImage || 'None'}`);
        }
      });
    } catch(e) {
      console.error(e.message, data.substring(0, 100));
    }
  });
}).on('error', console.error);
