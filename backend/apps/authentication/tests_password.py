from django.core.exceptions import ValidationError
from django.test import SimpleTestCase

from .validators import ReglasContrasenaValidator


class ReglasContrasenaTests(SimpleTestCase):
    def setUp(self):
        self.validador = ReglasContrasenaValidator()

    def test_contrasenas_validas(self):
        for clave in ("Clave-Segura-2026", "Hola*12abc", "abc12*xyz", "Examen_24_ok", "Ab1*Cd2*Ef"):
            with self.subTest(clave=clave):
                self.validador.validate(clave)  # no lanza

    def test_contrasenas_invalidas(self):
        casos = {
            "Ab1*": "corta",
            "abcdefgh*": "sin números",
            "12345*78": "solo números y símbolo, sin letras",
            "Abcdefg1": "sin carácter especial",
            "Clave123*x": "123 consecutivos",
            "Clave987*x": "987 consecutivos descendentes",
            "Clave*1234": "1234 consecutivos",
            "x9*0123abc": "012 consecutivos",
        }
        for clave, motivo in casos.items():
            with self.subTest(clave=clave, motivo=motivo):
                with self.assertRaises(ValidationError):
                    self.validador.validate(clave)

    def test_dos_numeros_consecutivos_si_se_permiten(self):
        self.validador.validate("Clave12*x")
        self.validador.validate("Clave*23xy")
        self.validador.validate("Clave*1a2b3")  # no están pegados
