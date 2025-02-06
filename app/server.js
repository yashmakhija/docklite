const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.post('/encode', (req, res) => {
    const { text } = req.body;
    if (!text) {
        return res.status(400).json({ error: 'Text is required' });
    }
    const encoded = Buffer.from(text).toString('base64');
    res.json({ result: encoded });
});

app.post('/decode', (req, res) => {
    const { text } = req.body;
    if (!text) {
        return res.status(400).json({ error: 'Text is required' });
    }
    try {
        const decoded = Buffer.from(text, 'base64').toString('utf-8');
        res.json({ result: decoded });
    } catch (error) {
        res.status(400).json({ error: 'Invalid base64 string' });
    }
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
}); 