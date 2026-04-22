import os
import qrcode
from io import BytesIO
from dotenv import load_dotenv

load_dotenv()

def generate_table_qr(table_id: int) -> bytes:
    base_url = os.getenv("API_BASE_URL", "http://127.0.0.1:8000")
    url = f"{base_url}/mesas/validar-qr?mesa={table_id}"

    qr = qrcode.make(url)
    buffer = BytesIO()
    qr.save(buffer, format="PNG")
    buffer.seek(0)

    return buffer.getvalue()
