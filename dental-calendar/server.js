const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
const { AccessToken } = require('livekit-server-sdk');
const WebSocket = require('ws');
const url = require('url');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
  },
  allowEIO3: true,
  transports: ['polling', 'websocket']
});

console.log('Socket.IO server initialized');

// Middleware
app.use(cors());

// Skip ngrok browser warning
app.use((req, res, next) => {
  res.setHeader('ngrok-skip-browser-warning', 'true');
  next();
});

app.use(bodyParser.json());
app.use(express.static('public'));

// Simple WebSocket proxy for LiveKit
const livekitTarget = process.env.LIVEKIT_URL || 'ws://localhost:7880';

// Create a WebSocket server for proxying
const wss = new WebSocket.Server({ noServer: true });

wss.on('connection', (clientWs, request) => {
  console.log('🔄 New WebSocket proxy connection to LiveKit');
  console.log('Request URL:', request.url);
  console.log('Request headers:', request.headers);
  
  // Create connection to LiveKit
  // Extract the actual path after /livekit-proxy
  const targetPath = request.url.replace('/livekit-proxy', '') || '';
  // LiveKit expects /rtc for WebSocket connections
  const targetUrl = livekitTarget + (targetPath || '/rtc');
  console.log('Target URL:', targetUrl);
  console.log('Headers:', JSON.stringify(request.headers, null, 2));
  
  // Forward important headers
  const headers = {
    'User-Agent': request.headers['user-agent'] || 'LiveKit-Proxy/1.0',
  };
  
  // Forward WebSocket protocol if present
  if (request.headers['sec-websocket-protocol']) {
    headers['Sec-WebSocket-Protocol'] = request.headers['sec-websocket-protocol'];
  }
  
  // Forward authorization if present
  if (request.headers['authorization']) {
    headers['Authorization'] = request.headers['authorization'];
  }
  
  // Create WebSocket with options
  const wsOptions = {
    headers: headers,
    perMessageDeflate: false,
    followRedirects: true
  };
  
  const livekitWs = new WebSocket(targetUrl, wsOptions);
  
  // Handle LiveKit connection open
  livekitWs.on('open', () => {
    console.log('✅ Connected to LiveKit server');
    // If LiveKit accepted a subprotocol, relay it back to client
    if (livekitWs.protocol) {
      clientWs.protocol = livekitWs.protocol;
    }
  });
  
  // Proxy messages from client to LiveKit
  clientWs.on('message', (data) => {
    if (livekitWs.readyState === WebSocket.OPEN) {
      livekitWs.send(data);
    }
  });
  
  // Proxy messages from LiveKit to client
  livekitWs.on('message', (data) => {
    if (clientWs.readyState === WebSocket.OPEN) {
      clientWs.send(data);
    }
  });
  
  // Handle errors
  clientWs.on('error', (err) => console.error('Client WS error:', err));
  livekitWs.on('error', (err) => {
    console.error('LiveKit WS error:', err);
    clientWs.close(1001, 'LiveKit connection failed');
  });
  
  // Handle close
  clientWs.on('close', (code, reason) => {
    console.log('Client disconnected:', code, reason);
    livekitWs.close();
  });
  livekitWs.on('close', (code, reason) => {
    console.log('LiveKit disconnected:', code, reason);
    clientWs.close();
  });
});

// Database setup
const db = new sqlite3.Database('./dental_calendar.db');

// Create tables
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    email TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER,
    patient_name TEXT NOT NULL,
    phone TEXT,
    date TEXT NOT NULL,
    time TEXT NOT NULL,
    end_time TEXT,
    treatment_type TEXT,
    notes TEXT,
    status TEXT DEFAULT 'confirmed',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients (id)
  )`);

  // No test data - clean start for production
  console.log('Datenbank bereit - Kalender startet mit leerer Termindatenbank');
});

// API Routes

// Get all appointments
app.get('/api/appointments', (req, res) => {
  db.all(`SELECT * FROM appointments ORDER BY date, time`, (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    // Format for FullCalendar
    const events = rows.map(appointment => ({
      id: appointment.id,
      title: `${appointment.patient_name} - ${appointment.treatment_type || 'Termin'}`,
      start: `${appointment.date}T${appointment.time}`,
      end: appointment.end_time ? `${appointment.date}T${appointment.end_time}` : null,
      backgroundColor: getStatusColor(appointment.status),
      extendedProps: {
        patientName: appointment.patient_name,
        phone: appointment.phone,
        treatmentType: appointment.treatment_type,
        notes: appointment.notes,
        status: appointment.status
      }
    }));
    
    res.json(events);
  });
});

// Create new appointment
app.post('/api/appointments', (req, res) => {
  const { patient_name, phone, date, time, end_time, treatment_type, notes } = req.body;
  
  db.run(`INSERT INTO appointments (patient_name, phone, date, time, end_time, treatment_type, notes) 
          VALUES (?, ?, ?, ?, ?, ?, ?)`, 
         [patient_name, phone, date, time, end_time, treatment_type, notes], 
         function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    const newAppointment = {
      id: this.lastID,
      patient_name,
      phone,
      date,
      time,
      end_time,
      treatment_type,
      notes,
      status: 'confirmed'
    };
    
    // Notify all clients
    io.emit('appointmentCreated', newAppointment);
    
    res.json(newAppointment);
  });
});

// Update appointment
app.put('/api/appointments/:id', (req, res) => {
  const { id } = req.params;
  const { date, time, end_time, status } = req.body;
  
  db.run(`UPDATE appointments SET date = ?, time = ?, end_time = ?, status = ? WHERE id = ?`,
         [date, time, end_time, status, id], 
         function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    // Notify all clients
    io.emit('appointmentUpdated', { id, date, time, end_time, status });
    
    res.json({ success: true });
  });
});

// Delete appointment
app.delete('/api/appointments/:id', (req, res) => {
  const { id } = req.params;
  
  db.run(`DELETE FROM appointments WHERE id = ?`, [id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    // Notify all clients
    io.emit('appointmentDeleted', { id });
    
    res.json({ success: true });
  });
});

// Sofia API Endpoints

// Heutige Termine für Sofia vorlesen
app.get('/api/sofia/today', (req, res) => {
  const today = new Date().toISOString().split('T')[0];
  
  db.all(`SELECT * FROM appointments WHERE date = ? ORDER BY time`, [today], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (rows.length === 0) {
      res.json({
        message: "Heute sind keine Termine geplant.",
        appointments: []
      });
      return;
    }
    
    let message = `Heute, ${formatDate(today)}, haben wir ${rows.length} Termine: `;
    const appointmentTexts = rows.map(apt => {
      const time = apt.time.substring(0, 5);
      return `um ${time} Uhr ${apt.patient_name} für ${apt.treatment_type || 'eine Behandlung'}`;
    });
    
    message += appointmentTexts.join(', ') + '.';
    
    res.json({
      message,
      appointments: rows,
      count: rows.length
    });
  });
});

// Termine eines Patienten für Sofia
app.get('/api/sofia/patient/:phone', (req, res) => {
  const phone = req.params.phone.replace(/[^\d+]/g, '');
  const today = new Date().toISOString().split('T')[0];
  
  db.all(`SELECT * FROM appointments WHERE phone = ? AND date >= ? ORDER BY date, time`, 
         [phone, today], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (rows.length === 0) {
      res.json({
        message: "Sie haben aktuell keine anstehenden Termine bei uns.",
        appointments: []
      });
      return;
    }
    
    let message = `Sie haben ${rows.length} anstehende Termine: `;
    const appointmentTexts = rows.map(apt => {
      const date = formatDate(apt.date);
      const time = apt.time.substring(0, 5);
      const treatment = apt.treatment_type || 'Behandlung';
      return `${date} um ${time} Uhr für ${treatment}`;
    });
    
    message += appointmentTexts.join(', ') + '.';
    
    res.json({
      message,
      appointments: rows,
      count: rows.length
    });
  });
});

// Wochenübersicht für Sofia
app.get('/api/sofia/week', (req, res) => {
  const today = new Date();
  const weekStart = new Date(today);
  weekStart.setDate(today.getDate() - today.getDay() + 1); // Montag
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekStart.getDate() + 6); // Sonntag
  
  const startDate = weekStart.toISOString().split('T')[0];
  const endDate = weekEnd.toISOString().split('T')[0];
  
  db.all(`SELECT * FROM appointments WHERE date BETWEEN ? AND ? ORDER BY date, time`, 
         [startDate, endDate], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (rows.length === 0) {
      res.json({
        message: "Diese Woche sind keine Termine geplant.",
        appointments: []
      });
      return;
    }
    
    // Gruppiere nach Tagen
    const dayGroups = {};
    rows.forEach(apt => {
      const dayName = getDayName(apt.date);
      if (!dayGroups[dayName]) dayGroups[dayName] = [];
      dayGroups[dayName].push(apt);
    });
    
    let message = `Diese Woche haben wir Termine an ${Object.keys(dayGroups).length} Tagen: `;
    const dayTexts = Object.entries(dayGroups).map(([day, appointments]) => {
      return `${day} ${appointments.length} Termine`;
    });
    
    message += dayTexts.join(', ') + '.';
    
    res.json({
      message,
      appointments: rows,
      dayGroups,
      count: rows.length
    });
  });
});

// Kommende Termine (nächste 30 Tage)
app.get('/api/sofia/upcoming', (req, res) => {
  const today = new Date().toISOString().split('T')[0];
  const future = new Date();
  future.setDate(future.getDate() + 30);
  const futureDate = future.toISOString().split('T')[0];
  
  db.all(`SELECT * FROM appointments WHERE date BETWEEN ? AND ? ORDER BY date, time LIMIT 10`, 
         [today, futureDate], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (rows.length === 0) {
      res.json({
        message: "In den nächsten 30 Tagen sind keine Termine geplant.",
        appointments: []
      });
      return;
    }
    
    let message = `In den nächsten 30 Tagen haben wir ${rows.length} Termine. `;
    if (rows.length > 0) {
      const next = rows[0];
      const nextDate = formatDate(next.date);
      const nextTime = next.time.substring(0, 5);
      message += `Der nächste Termin ist ${nextDate} um ${nextTime} Uhr mit ${next.patient_name}.`;
    }
    
    res.json({
      message,
      appointments: rows,
      count: rows.length
    });
  });
});

// Nächsten freien Termin finden
app.get('/api/sofia/next-available', (req, res) => {
  const today = new Date();
  const maxDaysToCheck = 30;
  const businessHours = ['08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', 
                         '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30'];
  
  const checkDate = new Date(today);
  
  function findAvailableSlot(currentDate, dayCount = 0) {
    if (dayCount > maxDaysToCheck) {
      res.json({
        message: "In den nächsten 30 Tagen sind leider alle Termine belegt. Bitte rufen Sie uns direkt an.",
        available: false
      });
      return;
    }
    
    // Skip weekends
    if (currentDate.getDay() === 0 || currentDate.getDay() === 6) {
      currentDate.setDate(currentDate.getDate() + 1);
      return findAvailableSlot(currentDate, dayCount + 1);
    }
    
    const dateStr = currentDate.toISOString().split('T')[0];
    
    // Get existing appointments for this date
    db.all(`SELECT time FROM appointments WHERE date = ? ORDER BY time`, [dateStr], (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      const bookedTimes = rows.map(row => row.time.substring(0, 5));
      const availableTimes = businessHours.filter(time => !bookedTimes.includes(time));
      
      if (availableTimes.length > 0) {
        const nextTime = availableTimes[0];
        const formattedDate = formatDate(dateStr);
        
        res.json({
          message: `Der nächste freie Termin ist ${formattedDate} um ${nextTime} Uhr.`,
          available: true,
          date: dateStr,
          time: nextTime,
          formattedDate: formattedDate,
          allAvailableTimes: availableTimes.slice(0, 5) // Show first 5 options
        });
      } else {
        // No slots available today, try next day
        currentDate.setDate(currentDate.getDate() + 1);
        findAvailableSlot(currentDate, dayCount + 1);
      }
    });
  }
  
  findAvailableSlot(checkDate);
});

// Verfügbarkeit an bestimmtem Tag prüfen
app.get('/api/sofia/check-date/:date', (req, res) => {
  const requestedDate = req.params.date;
  const date = new Date(requestedDate);
  
  // Validate date format
  if (isNaN(date.getTime())) {
    res.status(400).json({
      message: "Ungültiges Datumsformat. Bitte verwenden Sie YYYY-MM-DD.",
      available: false
    });
    return;
  }
  
  // Check if it's a weekend
  if (date.getDay() === 0 || date.getDay() === 6) {
    res.json({
      message: "Am Wochenende haben wir geschlossen. Bitte wählen Sie einen Wochentag.",
      available: false,
      isWeekend: true
    });
    return;
  }
  
  // Check if date is in the past
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (date < today) {
    res.json({
      message: "Dieses Datum liegt in der Vergangenheit. Bitte wählen Sie ein zukünftiges Datum.",
      available: false,
      isPast: true
    });
    return;
  }
  
  const businessHours = ['08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', 
                         '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30'];
  
  db.all(`SELECT time FROM appointments WHERE date = ? ORDER BY time`, [requestedDate], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    const bookedTimes = rows.map(row => row.time.substring(0, 5));
    const availableTimes = businessHours.filter(time => !bookedTimes.includes(time));
    const formattedDate = formatDate(requestedDate);
    
    if (availableTimes.length > 0) {
      res.json({
        message: `Am ${formattedDate} haben wir noch ${availableTimes.length} freie Termine: ${availableTimes.slice(0, 5).join(', ')} Uhr.`,
        available: true,
        date: requestedDate,
        formattedDate: formattedDate,
        availableTimes: availableTimes,
        bookedTimes: bookedTimes,
        totalSlots: businessHours.length,
        freeSlots: availableTimes.length
      });
    } else {
      res.json({
        message: `Am ${formattedDate} sind leider alle Termine belegt. Soll ich Ihnen Alternativen vorschlagen?`,
        available: false,
        date: requestedDate,
        formattedDate: formattedDate,
        bookedTimes: bookedTimes,
        totalSlots: businessHours.length,
        freeSlots: 0
      });
    }
  });
});

// Terminvorschläge für die nächsten Tage
app.get('/api/sofia/suggest-times', (req, res) => {
  const daysToCheck = parseInt(req.query.days) || 7; // Default 7 Tage
  const maxSuggestions = parseInt(req.query.limit) || 5; // Default 5 Vorschläge
  const today = new Date();
  const suggestions = [];
  
  const businessHours = ['08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', 
                         '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30'];
  
  function checkNextDay(dayOffset = 0) {
    if (dayOffset >= daysToCheck || suggestions.length >= maxSuggestions) {
      // Return collected suggestions
      if (suggestions.length > 0) {
        const suggestionText = suggestions.map(s => 
          `${s.formattedDate} um ${s.time} Uhr`
        ).join(', ');
        
        res.json({
          message: `Ich kann Ihnen folgende Termine vorschlagen: ${suggestionText}.`,
          suggestions: suggestions,
          count: suggestions.length
        });
      } else {
        res.json({
          message: `In den nächsten ${daysToCheck} Tagen sind leider keine Termine frei. Bitte rufen Sie uns direkt an.`,
          suggestions: [],
          count: 0
        });
      }
      return;
    }
    
    const checkDate = new Date(today);
    checkDate.setDate(today.getDate() + dayOffset);
    
    // Skip weekends
    if (checkDate.getDay() === 0 || checkDate.getDay() === 6) {
      return checkNextDay(dayOffset + 1);
    }
    
    const dateStr = checkDate.toISOString().split('T')[0];
    
    db.all(`SELECT time FROM appointments WHERE date = ? ORDER BY time`, [dateStr], (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      const bookedTimes = rows.map(row => row.time.substring(0, 5));
      const availableTimes = businessHours.filter(time => !bookedTimes.includes(time));
      
      // Add first available slot from this day
      if (availableTimes.length > 0 && suggestions.length < maxSuggestions) {
        suggestions.push({
          date: dateStr,
          time: availableTimes[0],
          formattedDate: formatDate(dateStr),
          availableCount: availableTimes.length
        });
      }
      
      checkNextDay(dayOffset + 1);
    });
  }
  
  checkNextDay(0);
});

// Sofia webhook endpoint
app.post('/api/sofia/appointment', (req, res) => {
  console.log('Sofia webhook received:', req.body);
  
  const { patientName, patientPhone, requestedDate, requestedTime, treatmentType } = req.body;
  
  // Check if time slot is available
  db.get(`SELECT id FROM appointments WHERE date = ? AND time = ?`, 
         [requestedDate, requestedTime], 
         (err, row) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (row) {
      // Time slot taken, suggest alternative
      res.json({
        success: false,
        message: 'Der gewünschte Termin ist bereits vergeben. Bitte wählen Sie eine andere Zeit.'
      });
      return;
    }
    
    // Create appointment
    const endTime = addMinutes(requestedTime, 30);
    
    db.run(`INSERT INTO appointments (patient_name, phone, date, time, end_time, treatment_type, notes) 
            VALUES (?, ?, ?, ?, ?, ?, ?)`,
           [patientName, patientPhone, requestedDate, requestedTime, endTime, treatmentType || 'Beratung', 'Via Sofia gebucht'],
           function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      const newAppointment = {
        id: this.lastID,
        patient_name: patientName,
        phone: patientPhone,
        date: requestedDate,
        time: requestedTime,
        end_time: endTime,
        treatment_type: treatmentType || 'Beratung',
        notes: 'Via Sofia gebucht',
        status: 'confirmed'
      };
      
      // Notify all clients in real-time
      io.emit('appointmentCreated', newAppointment);
      
      res.json({
        success: true,
        message: `Termin erfolgreich gebucht für ${requestedDate} um ${requestedTime} Uhr.`,
        appointment: newAppointment
      });
    });
  });
});

// Helper functions
function addMinutes(time, minutes) {
  const [hours, mins] = time.split(':').map(Number);
  const totalMinutes = hours * 60 + mins + minutes;
  const newHours = Math.floor(totalMinutes / 60);
  const newMins = totalMinutes % 60;
  return `${newHours.toString().padStart(2, '0')}:${newMins.toString().padStart(2, '0')}`;
}

function getStatusColor(status) {
  switch(status) {
    case 'confirmed': return '#28a745';
    case 'cancelled': return '#dc3545';
    case 'completed': return '#007bff';
    default: return '#6c757d';
  }
}

function formatDate(dateString) {
  const date = new Date(dateString);
  const options = { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  };
  return date.toLocaleDateString('de-DE', options);
}

function getDayName(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('de-DE', { weekday: 'long' });
}

// LiveKit token endpoint
app.post('/api/livekit-token', async (req, res) => {
  const { identity, room, metadata } = req.body;
  
  try {
    const roomName = room || 'sofia-room';
    const participantName = identity || 'calendar-user-' + Date.now();
    
    console.log(`🎟️ Generating LiveKit token for ${participantName} in room ${roomName}`);
    
    const token = await generateLiveKitToken(participantName, roomName);
    
    // Always use direct LiveKit connection now that we have separate tunnels
    const livekitUrl = process.env.LIVEKIT_URL || 'ws://localhost:7880';
    console.log(`📡 Using LiveKit URL: ${livekitUrl}`);
    
    res.json({
      token: token,
      url: livekitUrl,
      room: roomName,
      identity: participantName
    });
  } catch (error) {
    console.error('❌ Error generating LiveKit token:', error);
    res.status(500).json({ error: 'Failed to generate token' });
  }
});

// Sofia connection endpoint for voice chat
app.post('/api/sofia/connect', async (req, res) => {
  const { participantName, roomName } = req.body;
  
  try {
    const token = await generateLiveKitToken(participantName, roomName);
    
    console.log(`🎤 User connecting to room: ${roomName}, dispatching Sofia agent...`);
    
    // Dispatch Sofia agent to the room using LiveKit API
    await dispatchSofiaToRoom(roomName);
    
    // Also send a manual dispatch signal to ensure Sofia joins
    setTimeout(async () => {
      console.log(`🔄 Backup dispatch for room: ${roomName}`);
      await triggerSofiaManually(roomName);
    }, 5000);
    
    // Determine if this is an external request
    const isExternal = req.headers.host?.includes('ngrok') || 
                      req.headers['x-forwarded-host']?.includes('ngrok') ||
                      req.headers.origin?.includes('ngrok') ||
                      req.headers.origin?.includes('elosofia');
    
    // Use ngrok URL for external requests, local URL for internal
    const livekitUrl = isExternal 
      ? 'wss://0ac90f1eb152.ngrok-free.app/livekit-proxy'  // WebSocket proxy path
      : (process.env.LIVEKIT_URL || 'ws://localhost:7880');
    console.log(`📡 Sofia connect - Using LiveKit URL: ${livekitUrl}`);
    
    res.json({
      token: token,
      url: livekitUrl,
      roomName: roomName
    });
  } catch (error) {
    console.error('Error generating Sofia connection:', error);
    res.status(500).json({ error: 'Failed to generate connection token' });
  }
});

// Dispatch Sofia agent to a specific room
async function dispatchSofiaToRoom(roomName) {
  try {
    console.log(`📡 Dispatching Sofia agent to room: ${roomName}`);
    
    const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
    const apiSecret = process.env.LIVEKIT_API_SECRET || 'secret';
    const liveKitUrl = process.env.LIVEKIT_URL || 'ws://localhost:7880';
    
    // Convert WebSocket URL to HTTP for REST API
    const httpUrl = liveKitUrl.replace('ws://', 'http://').replace('wss://', 'https://');
    
    // Create dispatch request using LiveKit's agent dispatch API
    const dispatchUrl = `${httpUrl}/agents/dispatch`;
    
    const dispatchPayload = {
      agent_name: 'dental-assistant',
      room: roomName,
      metadata: {
        agent_type: 'sofia',
        language: 'multi',
        room_type: 'dental-calendar'
      }
    };
    
    // Make HTTP request to dispatch agent
    const fetch = (await import('node-fetch')).default;
    const response = await fetch(dispatchUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${createJWTForAPI(apiKey, apiSecret)}`
      },
      body: JSON.stringify(dispatchPayload)
    });
    
    if (response.ok) {
      const result = await response.text();
      console.log(`✅ Sofia successfully dispatched to room: ${roomName}`);
      console.log('Dispatch response:', result);
      return true;
    } else {
      // If dispatch API doesn't exist, try alternative approach
      console.log(`⚠️ Agent dispatch API not available (${response.status}), Sofia will join automatically when room has participants`);
      return true;
    }
    
  } catch (error) {
    console.log(`⚠️ Dispatch error (${error.message}), Sofia should join automatically when participants connect`);
    return true; // Don't fail the connection if dispatch fails
  }
}

// Manual trigger for Sofia to join room by creating a Sofia participant directly
async function triggerSofiaManually(roomName) {
  try {
    const { spawn } = require('child_process');
    const path = require('path');
    
    console.log(`🤖 Manually spawning Sofia for room: ${roomName}`);
    
    // Create a dedicated Sofia process for this room
    const agentPath = path.join(__dirname, '..', 'agent.py');
    const pythonProcess = spawn('python', [agentPath, 'connect', roomName], {
      cwd: path.join(__dirname, '..'),
      stdio: 'pipe'
    });
    
    pythonProcess.stdout.on('data', (data) => {
      console.log(`Sofia (${roomName}):`, data.toString());
    });
    
    pythonProcess.stderr.on('data', (data) => {
      console.log(`Sofia Error (${roomName}):`, data.toString());
    });
    
    console.log(`✅ Sofia process started for room: ${roomName}`);
    return true;
    
  } catch (error) {
    console.log(`⚠️ Manual Sofia spawn failed: ${error.message}`);
    return false;
  }
}

// Helper function to create JWT for LiveKit API
function createJWTForAPI(apiKey, apiSecret) {
  const at = new AccessToken(apiKey, apiSecret, {
    identity: 'server-admin',
    ttl: '1h',
  });
  at.addGrant({ roomAdmin: true });
  return at.toJwt();
}

// Helper function to generate LiveKit token
async function generateLiveKitToken(participantName, roomName) {
  const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
  const apiSecret = process.env.LIVEKIT_API_SECRET || 'secret';
  
  const at = new AccessToken(apiKey, apiSecret, {
    identity: participantName,
    ttl: '10h',
  });
  
  at.addGrant({ 
    roomJoin: true, 
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true
  });
  
  // Add metadata to request agent dispatch
  at.metadata = JSON.stringify({
    request_agent: true,
    agent_type: 'dental-assistant'
  });
  
  return await at.toJwt();
}

// Socket.io connection
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'dental-calendar',
    timestamp: new Date().toISOString()
  });
});

// Serve main page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Sofia token endpoint for debugging
app.post('/api/sofia/token', async (req, res) => {
  const { participant_name } = req.body;
  const roomName = 'sofia-dental-' + Date.now();
  
  try {
    const token = await generateLiveKitToken(
      participant_name || 'Debug User ' + Date.now(),
      roomName
    );
    
    // For external clients, use the proxied URL through ngrok
    const isExternalRequest = req.headers['ngrok-skip-browser-warning'] === 'true' || 
                            req.headers.host?.includes('ngrok') ||
                            req.headers.origin?.includes('https');
    
    const livekitUrl = isExternalRequest 
      ? 'wss://0ac90f1eb152.ngrok-free.app/livekit-proxy'
      : (process.env.LIVEKIT_URL || 'ws://localhost:7880');
    
    console.log(`🎟️ Generated debug token for ${participant_name} in room ${roomName} (URL: ${livekitUrl})`);
    
    res.json({
      token,
      url: livekitUrl,
      roomName
    });
  } catch (error) {
    console.error('Error generating token:', error);
    res.status(500).json({ error: 'Failed to generate token: ' + error.message });
  }
});

const PORT = process.env.PORT || 3005;
server.listen(PORT, () => {
  console.log(`Dental Calendar Server running on http://localhost:${PORT}`);
  console.log('Sofia Webhook: POST /api/sofia/appointment');
  console.log(`LiveKit WebSocket Proxy: ws://localhost:${PORT}/livekit-proxy`);
  if (process.env.NGROK_URL) {
    console.log(`External access via: ${process.env.NGROK_URL}`);
  }
});

// Handle WebSocket upgrade for LiveKit proxy
server.on('upgrade', (request, socket, head) => {
  const pathname = url.parse(request.url).pathname;
  
  if (pathname.startsWith('/livekit-proxy')) {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  } else {
    socket.destroy();
  }
});