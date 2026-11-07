from pathlib import Path
import os

from dotenv import load_dotenv
from google import genai

# Load the private API key.
ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    raise ValueError("Gemini API key not found")

# Connect to Gemini.
client = genai.Client(api_key=api_key)

# Send our first prompt.
response = client.models.generate_content(
    model="gemini-3.5-flash-lite",
    contents="Reply exactly: Gemini connection successful"
)

print(response.text)