import asyncio
import sys
sys.path.insert(0, '/app')

from src.dental.dental_tools import KalenderClient

async def test_calendar_fix():
    k = KalenderClient()
    print(f"KalenderClient URL: {k.calendar_url}")
    
    # Test next available
    res = await k.get_next_available()
    print(f"Next available result: {res}")
    
    # Test appointment booking
    booking_res = await k.book_appointment(
        patient_name="Test Sofia",
        patient_phone="+491234567890",
        requested_date="2025-07-31",
        requested_time="14:00",
        treatment_type="Test"
    )
    print(f"Booking result: {booking_res}")

if __name__ == "__main__":
    asyncio.run(test_calendar_fix())