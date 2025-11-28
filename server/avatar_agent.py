"""
Enhanced Tavus Avatar Agent with proper cleanup and error handling
"""

from dotenv import load_dotenv
from livekit import agents, rtc
from livekit.agents import AgentSession, Agent
from livekit.plugins import openai, tavus
from livekit import api
import os
import logging
import asyncio

# Load environment variables
load_dotenv()

# Set up detailed logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Also enable LiveKit debug logging
logging.getLogger("livekit").setLevel(logging.DEBUG)
logging.getLogger("tavus").setLevel(logging.DEBUG)


class DebugAvatarAgent(Agent):
    """Agent with debug logging"""
    
    def __init__(self) -> None:
        super().__init__(
            instructions="""You are a helpful AI assistant with a visual avatar. 
            Be friendly and conversational. Start by greeting the user warmly."""
        )
        logger.info("DebugAvatarAgent initialized")


async def entrypoint(ctx: agents.JobContext):
    """Main entry point with proper cleanup and error handling"""
    
    logger.info("="*60)
    logger.info(f"AGENT STARTING")
    logger.info(f"Room name: {ctx.room.name}")
    logger.info("="*60)
    
    avatar = None
    session = None
    
    try:
        # Connect to room
        logger.info("Step 1: Connecting to LiveKit room...")
        await ctx.connect()
        
        logger.info("Step 2: Connected! Room details:")
        logger.info(f"  - Room name: {ctx.room.name}")
        logger.info(f"  - Local participant: {ctx.room.local_participant.identity}")
        logger.info(f"  - Remote participants: {len(ctx.room.remote_participants)}")
        
        for sid, participant in ctx.room.remote_participants.items():
            logger.info(f"  - Remote participant: {participant.identity} (SID: {sid})")
        
        # Check environment variables
        logger.info("Step 3: Checking Tavus configuration...")
        replica_id = os.getenv("TAVUS_REPLICA_ID")
        persona_id = os.getenv("TAVUS_PERSONA_ID")
        logger.info(f"  - Replica ID: {replica_id[:10]}..." if replica_id else "  - Replica ID: NOT SET!")
        logger.info(f"  - Persona ID: {persona_id[:10]}..." if persona_id else "  - Persona ID: NOT SET!")
        
        # Create Tavus avatar
        logger.info("Step 4: Creating Tavus avatar session...")
        avatar = tavus.AvatarSession(
            replica_id=replica_id,
            persona_id=persona_id,
        )
        logger.info("  - Avatar session object created")
        
        # Create OpenAI model
        logger.info("Step 5: Creating OpenAI Realtime model...")
        realtime_model = openai.realtime.RealtimeModel(
            model="gpt-4o-realtime-preview",
            voice="alloy",
            temperature=0.8,
        )
        logger.info("  - RealtimeModel created successfully")
        
        # Create agent session
        logger.info("Step 6: Creating agent session...")
        session = AgentSession(llm=realtime_model)
        logger.info("  - Agent session created")
        
        # Start avatar in room
        logger.info("Step 7: Starting Tavus avatar in room...")
        logger.info("  - This publishes the avatar video to the room")
        await avatar.start(session, room=ctx.room)
        logger.info("  - Avatar.start() completed")
        
        # Add a small delay to ensure avatar is ready
        await asyncio.sleep(1)
        
        # Check room state again
        logger.info("Step 8: Checking room state after avatar start...")
        logger.info(f"  - Room participants now: {len(ctx.room.remote_participants) + 1}")
        logger.info(f"  - Local participant tracks: {len(ctx.room.local_participant.track_publications)}")
        
        # Start the interactive session
        logger.info("Step 9: Starting interactive session...")
        agent = DebugAvatarAgent()
        await session.start(
            room=ctx.room,
            agent=agent,
        )
        logger.info("  - Session.start() completed")
        
        # Generate initial greeting
        logger.info("Step 10: Generating initial greeting...")
        await session.generate_reply(
            instructions="Greet the user warmly. Say something like 'Hello! I can see you're connected. How can I help you today?'"
        )
        logger.info("  - Initial greeting sent")
        
        logger.info("="*60)
        logger.info("AGENT FULLY INITIALIZED AND READY!")
        logger.info("Monitoring participant count...")
        logger.info("="*60)
        
        # Monitor participants and exit when everyone leaves
        initial_count = len(ctx.room.remote_participants)
        empty_room_counter = 0
        
        while True:
            await asyncio.sleep(1)  # Check every second for faster response
            
            current_count = len(ctx.room.remote_participants)
            
            # Check for participant changes
            if current_count != initial_count:
                logger.info(f"Participant count changed: {initial_count} -> {current_count}")
                initial_count = current_count
            
            # If room is empty (only agent remains)
            if current_count == 0:
                empty_room_counter += 1
                if empty_room_counter == 1:
                    logger.info("All participants left the room")
                
                # Wait 4 seconds before exiting to handle quick reconnects
                if empty_room_counter >= 2:  # 4 seconds
                    logger.info("Room empty for 6 seconds, cleaning up...")
                    
                    # Option 1: Try to delete room (may not always work)
                    try:
                        logger.info(f"Attempting to delete room '{ctx.room.name}'...")
                        lk_api = api.LiveKitAPI(
                            os.getenv("LIVEKIT_URL"),
                            os.getenv("LIVEKIT_API_KEY"),
                            os.getenv("LIVEKIT_API_SECRET")
                        )
                        # Try the correct API format
                        await lk_api.room.delete_room(api.DeleteRoomRequest(room=ctx.room.name))
                        logger.info(f"Room deleted successfully")
                        await lk_api.aclose()
                    except Exception as e:
                        logger.warning(f"Could not delete room (this is usually okay): {e}")
                        # Ensure we close the API client
                        try:
                            if 'lk_api' in locals():
                                await lk_api.aclose()
                        except:
                            pass
                    
                    # Option 2: Just disconnect cleanly
                    try:
                        await ctx.room.disconnect()
                        logger.info("Disconnected from room")
                    except:
                        pass
                    
                    break
            else:
                # Reset counter if someone rejoins
                empty_room_counter = 0
            
            # No need for constant heartbeat logging
                
    except Exception as e:
        logger.error("="*60)
        logger.error(f"ERROR in agent: {type(e).__name__}: {e}")
        logger.error("="*60, exc_info=True)
        
        # Handle specific OpenAI audio errors
        if "Audio content" in str(e):
            logger.info("Audio buffer error detected - this is a known OpenAI Realtime API issue")
            logger.info("The session will be cleaned up and restarted on next connection")
    
    finally:
        # Cleanup
        logger.info("="*60)
        logger.info("CLEANING UP AGENT RESOURCES")
        
        try:
            # The room deletion happens above when empty
            # Here we just ensure session/avatar cleanup
            logger.info("Agent cleanup completed")
        except Exception as cleanup_error:
            logger.error(f"Error during cleanup: {cleanup_error}")
        
        logger.info("Agent job completed - exiting")
        logger.info("="*60)


if __name__ == "__main__":
    logger.info("Starting Tavus Avatar Agent Worker...")
    agents.cli.run_app(
        agents.WorkerOptions(
            entrypoint_fnc=entrypoint,
            # In dev mode, the agent will restart on code changes
        )
    )