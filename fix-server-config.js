// Update the Sofia connect endpoint to use dev mode properly
const express = require('express');
const { AccessToken } = require('livekit-server-sdk');

// In dev mode, LiveKit expects these exact values
const LIVEKIT_API_KEY = 'devkey';
const LIVEKIT_API_SECRET = 'secret';
const LIVEKIT_URL = process.env.LIVEKIT_URL || 'ws://livekit:7880';

app.post('/api/sofia/connect', async (req, res) => {
    try {
        const { participantName, roomName } = req.body;
        
        console.log('Creating token for:', { participantName, roomName });
        console.log('Using LiveKit URL:', LIVEKIT_URL);
        
        // Create token with dev credentials
        const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
            identity: participantName,
        });
        
        token.addGrant({
            roomJoin: true,
            room: roomName,
            canPublish: true,
            canSubscribe: true,
            canPublishData: true
        });
        
        const jwt = token.toJwt();
        console.log('Token created successfully');
        
        res.json({
            token: jwt,
            url: LIVEKIT_URL,
            roomName: roomName
        });
    } catch (error) {
        console.error('Token creation error:', error);
        res.status(500).json({ error: error.message });
    }
});
