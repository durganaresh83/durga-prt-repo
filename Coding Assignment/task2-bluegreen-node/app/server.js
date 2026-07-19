const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const COLOR = process.env.DEPLOY_COLOR || 'unknown';

app.get('/', (req, res) => {
  res.json({ message: 'Hello from Node.js on EKS', color: COLOR, version: process.env.APP_VERSION || 'dev' });
});

app.get('/healthz', (req, res) => res.status(200).json({ status: 'ok', color: COLOR }));

app.listen(PORT, () => console.log(`Server (${COLOR}) listening on port ${PORT}`));
