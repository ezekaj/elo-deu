from dotenv import load_dotenv
import logging
import asyncio
import time
from aiohttp import web
import threading

from livekit import agents, rtc
from livekit.agents import AgentSession, Agent, RoomInputOptions
from livekit.plugins import (
    noise_cancellation,
)
from livekit.plugins import google
from src.agent.prompts import AGENT_INSTRUCTION, SESSION_INSTRUCTION
from src.dental.dental_tools import (
    schedule_appointment,
    check_availability,
    get_clinic_info,
    get_services_info,
    collect_patient_info,
    cancel_appointment,
    reschedule_appointment,
    answer_faq,
    get_insurance_info,
    get_payment_info,
    get_naechste_freie_termine,
    get_tagesplan_arzt,
    get_wochenuebersicht_arzt,
    termin_buchen_erweitert,
    get_patientenhistorie,
    termine_suchen_praxis,
    meine_termine_finden,
    medizinische_nachfragen_stellen,
    intelligente_terminbuchung_mit_nachfragen,
    namen_erkennen_und_speichern,
    intelligente_antwort_mit_namen_erkennung,
    gespraech_hoeflich_beenden,
    erkennung_gespraechsende_wunsch,
    intelligente_grund_nachfragen,
    conversational_repair,
    get_praxis_statistiken,
    termin_absagen,
    check_verfuegbarkeit_erweitert,
    parse_terminwunsch,
    get_aktuelle_datetime_info,
    get_intelligente_terminvorschlaege,
    termin_buchen_mit_details,
    termin_direkt_buchen,
    check_verfuegbarkeit_spezifisch,
    gespraech_beenden,
    notiz_hinzufuegen,
    gespraech_status,
    get_zeitabhaengige_begruessung,
    sofia_naechster_freier_termin,
    sofia_termin_an_bestimmtem_tag,
    sofia_terminvorschlaege_intelligent,
    sofia_heutige_termine_abrufen,
    sofia_meine_termine_finden_erweitert,
    termin_buchen_calendar_system,  # NEW: Calendar integration booking
    call_manager  # Import the call manager
)

load_dotenv()

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


class HealthServer:
    """Health check server for monitoring and webhooks"""
    def __init__(self, port=8080):
        self.port = port
        self.app = web.Application()
        self.is_connected = False
        self.setup_routes()
        
    def setup_routes(self):
        self.app.router.add_get('/health', self.health_check)
        self.app.router.add_post('/webhook/room-started', self.room_started)
        self.app.router.add_post('/webhook/participant-joined', self.participant_joined)
        
    async def health_check(self, request):
        return web.json_response({
            'status': 'ok',
            'service': 'sofia-agent',
            'livekit_connected': self.is_connected,
            'ready': True,
            'timestamp': int(time.time())
        })
        
    async def room_started(self, request):
        data = await request.json()
        logger.info(f"Room started webhook: {data}")
        return web.json_response({'status': 'ok'})
        
    async def participant_joined(self, request):
        data = await request.json()
        logger.info(f"Participant joined webhook: {data}")
        return web.json_response({'status': 'ok'})
        
    async def start(self):
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.port)
        await site.start()
        logger.info(f"Health server started on port {self.port}")

# Create global health server instance
health_server = HealthServer()


class DentalReceptionist(Agent):
    def __init__(self) -> None:
        super().__init__(
            instructions=AGENT_INSTRUCTION,
            llm=google.beta.realtime.RealtimeModel(
                voice="Aoede",  # Female voice for German
                language="de-DE",  # German language
                temperature=0.7,
            ),
            tools=[
                schedule_appointment,
                check_availability,
                get_clinic_info,
                get_services_info,
                collect_patient_info,
                cancel_appointment,
                reschedule_appointment,
                answer_faq,
                get_insurance_info,
                get_payment_info,
                get_naechste_freie_termine,
                get_tagesplan_arzt,
                get_wochenuebersicht_arzt,
                termin_buchen_erweitert,
                get_patientenhistorie,
                termine_suchen_praxis,
                meine_termine_finden,
                medizinische_nachfragen_stellen,
                intelligente_terminbuchung_mit_nachfragen,
                namen_erkennen_und_speichern,
                intelligente_antwort_mit_namen_erkennung,
                gespraech_hoeflich_beenden,
                erkennung_gespraechsende_wunsch,
                intelligente_grund_nachfragen,
                conversational_repair,
                get_praxis_statistiken,
                termin_absagen,
                check_verfuegbarkeit_erweitert,
                parse_terminwunsch,
                get_aktuelle_datetime_info,
                get_intelligente_terminvorschlaege,
                termin_buchen_mit_details,
                termin_direkt_buchen,
                check_verfuegbarkeit_spezifisch,
                gespraech_beenden,
                notiz_hinzufuegen,
                gespraech_status,
                get_zeitabhaengige_begruessung,
                sofia_naechster_freier_termin,
                sofia_termin_an_bestimmtem_tag,
                sofia_terminvorschlaege_intelligent,
                sofia_heutige_termine_abrufen,
                sofia_meine_termine_finden_erweitert,
                termin_buchen_calendar_system  # NEW: Calendar integration booking
            ],
        )
        self.should_end_conversation = False
    
    async def handle_response(self, response: str) -> str:
        """
        Verarbeitet die Antwort und prüft auf Gesprächsende-Signal
        KRITISCH: Bei Ende-Signal SOFORT beenden!
        """
        # Prüfe auf Ende-Signal
        if "*[CALL_END_SIGNAL]*" in response:
            self.should_end_conversation = True
            logging.info("🔴 Gesprächsende-Signal erkannt - Gespräch wird SOFORT beendet")
            # Entferne das Signal aus der Antwort
            response = response.replace("*[CALL_END_SIGNAL]*", "")
            
            # SOFORT beenden - keine weiteren Nachrichten!
            logging.info("🚨 KRITISCH: Gespräch MUSS SOFORT beendet werden!")
            
        # Prüfe auch den CallManager-Status
        if call_manager.is_conversation_ended():
            self.should_end_conversation = True
            logging.info("🔴 CallManager signalisiert Gesprächsende - SOFORT beenden")
            
        return response
    
    def is_conversation_ended(self) -> bool:
        """
        Prüft, ob das Gespräch beendet werden soll
        """
        return self.should_end_conversation or call_manager.is_conversation_ended()


async def entrypoint(ctx: agents.JobContext):
    print("\n" + "!" * 60)
    print("!!! SOFIA ENTRYPOINT TRIGGERED !!!")
    print("!" * 60)
    print(f"Room: {ctx.room.name}")
    print(f"Room participants: {len(ctx.room.remote_participants)}")
    print("Starte deutsche Zahnarzt-Assistentin mit Audio-Input...")
    logger.info("Starting German dental assistant agent")
    
    # Update health server connection status
    health_server.is_connected = True
    
    # Create the agent
    agent = DentalReceptionist()
    
    # Enhanced room input options for better audio reception
    room_input_options = RoomInputOptions(
        audio_enabled=True,
        video_enabled=False,
        # Enhanced noise cancellation
        noise_cancellation=noise_cancellation.BVC(),
    )
    
    # Start session
    session = AgentSession()
    
    # Add event handlers before connecting
    def on_track_published(publication: rtc.TrackPublication, participant: rtc.RemoteParticipant):
        async def handle_track():
            await on_track_published_async(publication, participant)
        asyncio.create_task(handle_track())
    
    async def on_track_published_async(publication: rtc.TrackPublication, participant: rtc.RemoteParticipant):
        print(f"Audio-Track erkannt: {publication.track_info.name}")
        logger.info(f"Audio track published: {publication.track_info.name}")
        
        if publication.track_info.kind == rtc.TrackKind.KIND_AUDIO:
            print("Mikrofon-Input aktiv!")
            logger.info("Microphone input active")
            
            # Subscribe to the audio track
            track = await publication.track()
            if track:
                print("🎤 Höre zu...")
                logger.info("Listening to audio track")
                
                # Start processing audio
                await session.process_track(track)
    
    ctx.room.on("track_published", on_track_published)
    
    def on_participant_connected(participant: rtc.RemoteParticipant):
        async def handle_participant():
            await on_participant_connected_async(participant)
        asyncio.create_task(handle_participant())
    
    async def on_participant_connected_async(participant: rtc.RemoteParticipant):
        print(f"Teilnehmer verbunden: {participant.identity}")
        logger.info(f"Participant connected: {participant.identity}")
    
    ctx.room.on("participant_connected", on_participant_connected)
    
    def on_data_received(data: rtc.DataPacket):
        async def handle_data():
            await on_data_received_async(data)
        asyncio.create_task(handle_data())
    
    async def on_data_received_async(data: rtc.DataPacket):
        print(f"Daten empfangen: {data.data}")
        logger.info(f"Data received: {data.data}")
    
    ctx.room.on("data_received", on_data_received)
    
    # Connect to the room
    await ctx.connect()
    print("Mit LiveKit-Raum verbunden")
    
    # Start the agent session
    await session.start(
        room=ctx.room,
        agent=agent,
        room_input_options=room_input_options,
    )
    
    print("🎯 Bereit zum Zuhören! Sprechen Sie jetzt...")
    logger.info("Agent ready to listen")
    
    # Generate initial greeting with AUTOMATIC date/time detection
    await session.generate_reply(
        instructions=SESSION_INSTRUCTION + "\n\n**WICHTIG**: Rufen Sie SOFORT `get_zeitabhaengige_begruessung()` für die automatische Begrüßung auf!",
    )
    
    # KEIN automatisches Gesprächsende-Monitoring
    # Sofia läuft kontinuierlich ohne Unterbrechungen
    
    # KEIN automatisches Monitoring - Sofia läuft kontinuierlich
    
    # Warte auf Shutdown - OHNE automatisches Beenden
    try:
        # Endlos-Schleife - Agent läuft kontinuierlich
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        logger.info("Agent manuell beendet")
    except Exception as e:
        logger.info(f"Agent Fehler: {e}")
        # Bei Fehlern weiter laufen lassen
        await asyncio.sleep(5)
    finally:
        # Cleanup nur bei echtem Shutdown
        print("Agent beendet")
        logger.info("Agent shutdown")


async def connect_to_room(room_name):
    """Direct connection to a specific room"""
    import os
    import requests
    import json
    
    print(f"DIRECT CONNECT TO ROOM: {room_name}")
    
    try:
        # Get token from the calendar server (same as web client does)
        response = requests.post('http://localhost:3005/api/sofia/connect', json={
            'participantName': f'Sofia-Agent-{room_name}',
            'roomName': room_name
        })
        
        if response.status_code == 200:
            data = response.json()
            token = data['token']
            url = data['url']
            
            print(f"Got token for Sofia, connecting to {url}")
            
            # Create room and connect
            from livekit import rtc
            room = rtc.Room()
            
            await room.connect(url, token)
            print(f"SOFIA CONNECTED TO ROOM: {room_name}")
            
            # Create a fake JobContext for the entrypoint
            class FakeJobContext:
                def __init__(self, room):
                    self.room = room
                async def connect(self):
                    pass  # Already connected
            
            # Run the entrypoint
            ctx = FakeJobContext(room)
            await entrypoint(ctx)
            
        else:
            print(f"Failed to get token: {response.status_code}")
            
    except Exception as e:
        print(f"Connection error: {e}")

async def start_health_server():
    """Start the health server"""
    await health_server.start()


if __name__ == "__main__":
    import sys
    import asyncio
    
    if len(sys.argv) > 1 and sys.argv[1] == "connect" and len(sys.argv) > 2:
        # Direct room connection mode
        room_name = sys.argv[2]
        print(f"Starting Sofia in direct connect mode for room: {room_name}")
        asyncio.run(connect_to_room(room_name))
    else:
        # Normal worker mode
        import os
        
        # Ensure environment variables are loaded
        load_dotenv()
        
        # Start health server in background
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.create_task(start_health_server())
        
        # Start a thread to run the event loop for health server
        def run_health_loop():
            asyncio.set_event_loop(loop)
            loop.run_forever()
        
        health_thread = threading.Thread(target=run_health_loop, daemon=True)
        health_thread.start()
        
        worker_options = agents.WorkerOptions(
            entrypoint_fnc=entrypoint,
            # Don't set agent_name to keep automatic dispatch enabled
            ws_url=os.getenv("LIVEKIT_URL", "ws://localhost:7880"),
            api_key=os.getenv("LIVEKIT_API_KEY", "devkey"),
            api_secret=os.getenv("LIVEKIT_API_SECRET", "secret"),
        )
        
        print("\n" + "=" * 60)
        print("SOFIA DENTAL ASSISTANT - WORKER MODE")
        print("THIS IS THE REAL SOFIA FROM agent.py")
        print("=" * 60)
        print(f"LiveKit URL: {worker_options.ws_url}")
        print(f"API Key: {worker_options.api_key}")
        print("Auto-dispatch: ENABLED (no agent_name set)")
        print("Health server: http://0.0.0.0:8080/health")
        print("Waiting for room assignments...")
        print("If you see 'SOFIA ENTRYPOINT TRIGGERED' below, Sofia is working!")
        print("=" * 60 + "\n")
        
        agents.cli.run_app(worker_options)
