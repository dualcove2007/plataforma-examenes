import re

from django.core.exceptions import ValidationError


def _hay_digitos_consecutivos(clave):
    """True si hay 3 dígitos seguidos que suben (123) o bajan (321) de uno en uno."""
    for i in range(len(clave) - 2):
        trio = clave[i : i + 3]
        if not all("0" <= c <= "9" for c in trio):
            continue
        a, b, c = (int(x) for x in trio)
        if (b - a == 1 and c - b == 1) or (a - b == 1 and b - c == 1):
            return True
    return False


class ReglasContrasenaValidator:
    """Reglas de la plataforma (las mismas que valida la app móvil):

    - mínimo 8 caracteres (lo exige además MinimumLengthValidator)
    - al menos una letra y al menos un número
    - al menos un carácter especial
    - sin 3 o más dígitos consecutivos (123, 321...): 12 o 23 sí se permiten
    """

    def validate(self, password, user=None):
        errores = []
        if len(password) < 8:
            errores.append("Debe tener mínimo 8 caracteres.")
        if not re.search(r"[^\W\d_]", password):
            errores.append("Debe incluir al menos una letra.")
        if not re.search(r"[0-9]", password):
            errores.append("Debe incluir al menos un número.")
        if not re.search(r"[^\w\s]|_", password):
            errores.append("Debe incluir al menos un carácter especial (por ejemplo * . - _ #).")
        if _hay_digitos_consecutivos(password):
            errores.append("No puede tener 3 o más números consecutivos (por ejemplo 123 o 321).")
        if errores:
            raise ValidationError(errores, code="contrasena_invalida")

    def get_help_text(self):
        return (
            "Mínimo 8 caracteres, con letras, números y al menos un carácter especial. "
            "No puede tener 3 o más números consecutivos (123, 321)."
        )
