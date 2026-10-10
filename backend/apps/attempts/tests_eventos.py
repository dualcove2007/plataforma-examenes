"""Pruebas del anti-trampa: eventos del intento y resumen para el docente.

Ubicación: backend/apps/attempts/tests_eventos.py
Ejecutar:  python -m pytest apps/attempts/tests_eventos.py
"""
from apps.attempts.models import EventoIntento, Intento, ResultadoExamen
from apps.attempts.services import MAX_EVENTOS

from .tests_intentos import IntentosBase

Tipo = EventoIntento.Tipo
E = Intento.Estado


class EventosIntentoTests(IntentosBase):
    def evento(self, intento_id, tipo=Tipo.SALIDA_PESTANA, duracion=None, usuario=None):
        cuerpo = {"tipo": tipo}
        if duracion is not None:
            cuerpo["duracion_segundos"] = duracion
        return self.cliente(usuario or self.estudiante).post(
            f"/api/intentos/{intento_id}/eventos/", cuerpo, format="json"
        )

    # ------------------------------ registro ------------------------------
    def test_estudiante_registra_salida_de_pestana(self):
        intento_id = self.empezar()
        r = self.evento(intento_id, Tipo.SALIDA_PESTANA, 12)
        self.assertEqual(r.status_code, 201, r.content)
        ev = EventoIntento.objects.get(intento_id=intento_id)
        self.assertEqual(ev.tipo, Tipo.SALIDA_PESTANA)
        self.assertEqual(ev.duracion_segundos, 12)

    def test_registra_pegado_sin_duracion(self):
        intento_id = self.empezar()
        self.assertEqual(self.evento(intento_id, Tipo.PEGADO).status_code, 201)
        self.assertIsNone(EventoIntento.objects.get().duracion_segundos)

    def test_tipo_invalido_se_rechaza(self):
        intento_id = self.empezar()
        self.assertEqual(self.evento(intento_id, "otra_cosa").status_code, 400)

    def test_duracion_negativa_o_absurda_se_rechaza(self):
        intento_id = self.empezar()
        self.assertEqual(self.evento(intento_id, duracion=-5).status_code, 400)
        self.assertEqual(self.evento(intento_id, duracion=999999).status_code, 400)

    def test_sin_sesion_no_puede_registrar(self):
        intento_id = self.empezar()
        r = self.cliente().post(
            f"/api/intentos/{intento_id}/eventos/", {"tipo": Tipo.PEGADO}, format="json"
        )
        self.assertEqual(r.status_code, 401)

    def test_no_se_puede_registrar_en_intento_ajeno(self):
        intento_id = self.empezar()
        r = self.evento(intento_id, usuario=self.otro_estudiante)
        self.assertEqual(r.status_code, 404)
        self.assertEqual(EventoIntento.objects.count(), 0)

    def test_docente_no_puede_registrar_eventos(self):
        intento_id = self.empezar()
        r = self.evento(intento_id, usuario=self.docente)
        self.assertIn(r.status_code, (403, 404))
        self.assertEqual(EventoIntento.objects.count(), 0)

    def test_no_se_registra_en_intento_finalizado(self):
        intento_id = self.empezar()
        self.enviar(intento_id)
        self.assertEqual(self.evento(intento_id).status_code, 400)
        self.assertEqual(EventoIntento.objects.count(), 0)

    def test_no_se_registra_en_intento_vencido(self):
        intento_id = self.empezar()
        self.vencer(intento_id)
        self.assertEqual(self.evento(intento_id).status_code, 400)

    def test_hay_un_tope_de_eventos_por_intento(self):
        intento_id = self.empezar()
        EventoIntento.objects.bulk_create(
            [EventoIntento(intento_id=intento_id, tipo=Tipo.PEGADO) for _ in range(MAX_EVENTOS)]
        )
        self.assertEqual(self.evento(intento_id).status_code, 201)
        self.assertEqual(EventoIntento.objects.filter(intento_id=intento_id).count(), MAX_EVENTOS)

    # ------------------------------ resumen para el docente ------------------------------
    def rendir_con_eventos(self):
        intento_id = self.empezar()
        self.evento(intento_id, Tipo.SALIDA_PESTANA, 10)
        self.evento(intento_id, Tipo.SALIDA_PESTANA, 35)
        self.evento(intento_id, Tipo.PEGADO)
        self.enviar(intento_id)
        return ResultadoExamen.objects.get(intento_id=intento_id)

    def test_docente_ve_el_resumen_de_alertas(self):
        resultado = self.rendir_con_eventos()
        r = self.cliente(self.docente).get(f"/api/resultados/{resultado.pk}/")
        self.assertEqual(r.status_code, 200)
        alertas = r.json()["alertas"]
        self.assertEqual(alertas["salidas_pestana"], 2)
        self.assertEqual(alertas["segundos_fuera"], 45)
        self.assertEqual(alertas["pegados"], 1)
        self.assertEqual(len(alertas["eventos"]), 3)

    def test_sin_eventos_el_resumen_viene_en_cero(self):
        intento_id = self.empezar()
        self.enviar(intento_id)
        resultado = ResultadoExamen.objects.get(intento_id=intento_id)
        alertas = self.cliente(self.docente).get(f"/api/resultados/{resultado.pk}/").json()["alertas"]
        self.assertEqual(
            (alertas["salidas_pestana"], alertas["segundos_fuera"], alertas["pegados"]),
            (0, 0, 0),
        )
        self.assertEqual(alertas["eventos"], [])

    def test_el_estudiante_nunca_ve_las_alertas(self):
        resultado = self.rendir_con_eventos()
        c = self.cliente(self.estudiante)
        propio = c.get(f"/api/mis-resultados/{resultado.pk}/")
        self.assertEqual(propio.status_code, 200)
        self.assertNotIn("alertas", propio.json())
        self.assertNotIn("alertas", c.get(f"/api/intentos/{resultado.intento_id}/resultado/").json())

    def test_otro_docente_no_ve_las_alertas(self):
        resultado = self.rendir_con_eventos()
        r = self.cliente(self.otro_docente).get(f"/api/resultados/{resultado.pk}/")
        self.assertEqual(r.status_code, 404)