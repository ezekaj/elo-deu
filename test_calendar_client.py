import asyncio
import sys
sys.path.insert(0, '/app')

from src.utils.enhanced_calendar_client import EnhancedCalendarClient

async def test_calendar():
    client = EnhancedCalendarClient()
    print(f"Calendar URL: {client.calendar_url}")
    
    # Test health check
    health = await client.health_check()
    print(f"Health check result: {health}")
    
    # Test getting appointments
    try:
        appointments = await client.get_appointments()
        print(f"Appointments retrieved: {len(appointments) if appointments else 0}")
    except Exception as e:
        print(f"Error getting appointments: {e}")

if __name__ == "__main__":
    asyncio.run(test_calendar())