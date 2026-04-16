import qrcode
from io import BytesIO

def generate_table_qr(table_id: int) -> bytes:
    url = f"http://127.0.0.1:8000/mesas/validar-qr?mesa={table_id}"

    qr = qrcode.make(url)
    buffer = BytesIO()
    qr.save(buffer, format="PNG")
    buffer.seek(0)

    return buffer.getvalue()
