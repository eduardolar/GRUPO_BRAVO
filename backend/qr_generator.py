# ============================================================================
# backend/qr_generator.py
# ----------------------------------------------------------------------------
# Generador de códigos QR para mesas del restaurante.
#
# Cada mesa tiene un QR pegado a la superficie. Al escanearlo, el cliente
# abre la carta digital en su móvil ya asociada a esa mesa (no tiene que
# escribir el número).
#
# Devolvemos los BYTES de la imagen PNG en memoria (no escribimos archivo)
# para que el endpoint pueda enviar el binario directamente a Flutter:
#     return Response(content=generate_table_qr(...), media_type="image/png")
# ============================================================================
import qrcode
from io import BytesIO

def generate_table_qr(mesa_id, base_url="https://tu-app-bravo.com/mesa/"):
    """Genera un PNG con el QR que apunta a la URL de la mesa.

    Args:
        mesa_id: identificador único de la mesa (ObjectId stringificado).
        base_url: dominio del frontend. En producción se configura via env
                  para apuntar al dominio real del restaurante.

    Returns:
        bytes con el contenido PNG, listos para enviar como respuesta HTTP.
    """
    # Creamos el contenido del QR (la URL con el ID de la mesa).
    # Cuando el cliente escanea con el móvil, el navegador abre esta URL
    # y la app web/Flutter sabe a qué mesa está asociado.
    data = f"{base_url}{mesa_id}"

    # Configuración del QR
    #   version=1   → tamaño base (21x21 módulos); qrcode lo expande si hace falta.
    #   box_size=10 → cada "módulo" del QR mide 10 píxeles → QR de 210x210 mínimo.
    #   border=5    → borde blanco obligatorio (el estándar pide >= 4).
    qr = qrcode.QRCode(
        version=1,
        box_size=10,
        border=5
    )
    qr.add_data(data)
    # fit=True ajusta el version automáticamente si la URL es larga.
    qr.make(fit=True)

    # Creamos la imagen en blanco y negro (lo más legible para los lectores).
    img = qr.make_image(fill_color="black", back_color="white")

    # En lugar de guardar un archivo físico, lo devolvemos como bytes
    # para que la API pueda enviarlo directamente a Flutter sin tocar disco.
    # BytesIO = buffer en memoria con interfaz de archivo.
    buf = BytesIO()
    img.save(buf, format='PNG')
    return buf.getvalue()
