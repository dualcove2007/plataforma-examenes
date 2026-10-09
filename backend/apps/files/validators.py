from pathlib import Path

from rest_framework.exceptions import ValidationError

MB = 1024 * 1024

# extensión -> (tipo MIME real esperado, tamaño máximo en bytes)
TIPOS_PERMITIDOS = {
    ".pdf": ("application/pdf", 10 * MB),
    ".png": ("image/png", 5 * MB),
    ".jpg": ("image/jpeg", 5 * MB),
    ".jpeg": ("image/jpeg", 5 * MB),
}


def _detectar_mime(cabecera):
    """Identifica el tipo por los primeros bytes (firma), no por el nombre."""
    if b"%PDF-" in cabecera[:1024]:
        return "application/pdf"
    if cabecera.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if cabecera.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    return None


def validar_archivo(archivo):
    """Devuelve (nombre_limpio, mime) o lanza ValidationError."""
    nombre = Path(archivo.name or "").name  # descarta cualquier ruta que mande el cliente
    extension = Path(nombre).suffix.lower()

    if extension not in TIPOS_PERMITIDOS:
        raise ValidationError("Tipo de archivo no permitido. Solo PDF, PNG o JPG.")

    mime_esperado, maximo = TIPOS_PERMITIDOS[extension]

    if archivo.size == 0:
        raise ValidationError("El archivo está vacío.")
    if archivo.size > maximo:
        raise ValidationError(
            f"El archivo supera el máximo de {maximo // MB} MB para este tipo."
        )

    cabecera = archivo.read(1024)
    archivo.seek(0)
    if _detectar_mime(cabecera) != mime_esperado:
        raise ValidationError("El contenido del archivo no corresponde a su extensión.")

    return nombre, mime_esperado