from dotenv import load_dotenv
import logging
import asyncio

from livekit import agents, rtc
from livekit.agents import AgentSession, Agent, RoomInputOptions
from livekit.plugins import (
    noise_cancellation,
)
from livekit.plugins import google
from prompts import AGENT_INSTRUCTION, SESSION_INSTRUCTION
from dental_tools import (
    schedule_appointment,
    check_availability,
    get_clinic_info,
    get_services_info,
    collect_patient_info,
    cancel_appointment,
    reschedule_appointment,
    answer_faq,
    get_insurance_info,
    get_payment_info
)

load_dotenv()

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


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
                get_payment_info
            ],
        )


async def entrypoint(ctx: agents.JobContext):
    print("🎤 Starte deutsche Zahnarzt-Assistentin mit Audio-Input...")
    logger.info("Starting German dental assistant agent")
    
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
    @ctx.room.on("track_published")
    async def on_track_published(publication: rtc.TrackPublication, participant: rtc.RemoteParticipant):
        print(f"🎵 Audio-Track erkannt: {publication.track_info.name}")
        logger.info(f"Audio track published: {publication.track_info.name}")
        
        if publication.track_info.kind == rtc.TrackKind.KIND_AUDIO:
            print("✅ Mikrofon-Input aktiv!")
            logger.info("Microphone input active")
            
            # Subscribe to the audio track
            track = await publication.track()
            if track:
                print("🎤 Höre zu...")
                logger.info("Listening to audio track")
                
                # Start processing audio
                await session.process_track(track)
    
    @ctx.room.on("participant_connected")
    async def on_participant_connected(participant: rtc.RemoteParticipant):
        print(f"👋 Teilnehmer verbunden: {participant.identity}")
        logger.info(f"Participant connected: {participant.identity}")
    
    @ctx.room.on("data_received")
    async def on_data_received(data: rtc.DataPacket):
        print(f"📨 Daten empfangen: {data.data}")
        logger.info(f"Data received: {data.data}")
    
    # Connect to the room
    await ctx.connect()
    print("🔗 Mit LiveKit-Raum verbunden")
    
    # Start the agent session
    await session.start(
        room=ctx.room,
        agent=agent,
        room_input_options=room_input_options,
    )
    
    print("🎯 Bereit zum Zuhören! Sprechen Sie jetzt...")
    logger.info("Agent ready to listen")
    
    # Generate initial greeting
    await session.generate_reply(
        instructions=SESSION_INSTRUCTION,
    )
    
    # Keep the agent running
    await ctx.wait_for_shutdown()
    print("🛑 Agent beendet")
    logger.info("Agent shutdown")


if __name__ == "__main__":
    agents.cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
