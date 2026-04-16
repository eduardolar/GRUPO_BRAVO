import qrcode
from io import BytesIO

def generate_table_qr(mesa_id, base_url="https://tu-app-bravo.com/mesa/"):
    # Creamos el contenido del QR (la URL con el ID de la mesa)
    data = f"{base_url}{mesa_id}"
    
    # Configuración del QR
    qr = qrcode.QRCode(
        version=1,
        box_size=10,
        border=5
    )
    qr.add_data(data)
    qr.make(fit=True)

    # Creamos la imagen
    img = qr.make_image(fill_color="black", back_color="white")
    
    # En lugar de guardar un archivo físico, lo devolvemos como bytes 
    # para que la API pueda enviarlo directamente a Flutter
    buf = BytesIO()
    img.save(buf, format='PNG')
    return buf.getvalue()