const express = require('express');
const cors = require('cors');
const app = express();
app.use(cors());

const PORT = process.env.PORT || 4000;

app.get('/api/hello', (req, res) => {
  res.json({ message: 'Hello from the Node backend', env: process.env.NODE_ENV || 'development' });
});

app.get('/healthz', (req, res) => res.status(200).json({ status: 'ok' }));

app.listen(PORT, () => console.log(`Backend listening on ${PORT}`));
