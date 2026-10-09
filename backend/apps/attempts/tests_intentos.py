"""Pruebas del módulo attempts: iniciar, responder, enviar, calificar y privacidad.

Ubicación: backend/apps/attempts/tests_intentos.py
Ejecutar:  python -m pytest apps/attempts
"""
from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.attempts.models import Intento, RespuestaIntento, ResultadoExamen
from apps.audit.models import HistorialEstado
from apps.authentication.models import Usuario
from apps.exams.models import AsignacionExamen, Examen, ExamenPregunta
from apps.notifications.models import Notificacion
from apps.question_banks.models import (
    BancoPreguntas,
    Materia,
    OpcionRespuesta,
    Pregunta,
)

T = Pregunta.Tipo
E = Intento.Estado
R = ResultadoExamen.Revision


class IntentosBase(TestCase):
    """Examen de 4 preguntas con puntaje máximo total = 6.

    única (2) · múltiple (2) · verdadero/falso (1) · abierta (1)
    """

    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.admin = Usuario.objects.get(email="admin@demo.com")
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.otro_docente = Usuario.objects.create_user(
            "otro.doc@demo.com", "Otro Docente", "Demo12345*", rol=cls.docente.rol
        )
        cls.otro_estudiante = Usuario.objects.create_user(
            "otro.est@demo.com", "Otro Estudiante", "Demo12345*", rol=cls.estudiante.rol
        )

        cls.materia = Materia.objects.create(nombre="Redes")
        banco = BancoPreguntas.objects.create(
            materia=cls.materia, docente=cls.docente, titulo="Banco de prueba"
        )

        def pregunta(enunciado, tipo, puntaje, opciones=()):
            p = Pregunta.objects.create(
                banco=banco, enunciado=enunciado, tipo=tipo, puntaje=puntaje
            )
            creadas = [
                OpcionRespuesta.objects.create(pregunta=p, texto=t, es_correcta=ok)
                for t, ok in opciones
            ]
            return p, creadas

        cls.p_unica, (cls.unica_ok, cls.unica_mal) = pregunta(
            "Única", T.OPCION_UNICA, 2, [("A", True), ("B", False)]
        )
        cls.p_multiple, (cls.mult_1, cls.mult_2, cls.mult_mal) = pregunta(
            "Múltiple", T.OPCION_MULTIPLE, 2, [("M1", True), ("M2", True), ("M3", False)]
        )
        cls.p_vf, (cls.vf_v, cls.vf_f) = pregunta(
            "V/F", T.VERDADERO_FALSO, 1, [("Verdadero", True), ("Falso", False)]
        )
        cls.p_abierta, _ = pregunta("Abierta", T.ABIERTA, 1)
        # Pregunta que NO pertenece al examen
        cls.p_ajena, (cls.ajena_op,) = pregunta(
            "Ajena", T.OPCION_UNICA, 1, [("X", True)]
        )

    # ------------------------------ helpers ------------------------------
    def setUp(self):
        self.examen, self.asignacion = self.crear_examen()

    def crear_examen(
        self,
        estado=Examen.Estado.PUBLICADO,
        inicio=timedelta(hours=-1),
        fin=timedelta(hours=1),
        duracion=30,
        intentos=1,
        estudiante=None,
    ):
        ahora = timezone.now()
        examen = Examen.objects.create(
            docente=self.docente,
            materia=self.materia,
            titulo="Parcial",
            fecha_inicio=ahora + inicio,
            fecha_fin=ahora + fin,
            duracion_minutos=duracion,
            intentos_permitidos=intentos,
            estado=estado,
        )
        for orden, (p, puntaje) in enumerate(
            [
                (self.p_unica, 2),
                (self.p_multiple, 2),
                (self.p_vf, 1),
                (self.p_abierta, 1),
            ],
            start=1,
        ):
            ExamenPregunta.objects.create(
                examen=examen, pregunta=p, orden=orden, puntaje=puntaje
            )
        asignacion = AsignacionExamen.objects.create(
            examen=examen, estudiante=estudiante or self.estudiante
        )
        return examen, asignacion

    def cliente(self, usuario=None):
        c = APIClient()
        if usuario:
            c.force_authenticate(usuario)
        return c

    def iniciar(self, usuario=None, asignacion=None):
        return self.cliente(usuario or self.estudiante).post(
            "/api/intentos/",
            {"asignacion": (asignacion or self.asignacion).pk},
            format="json",
        )

    def empezar(self, **kw):
        r = self.iniciar(**kw)
        self.assertEqual(r.status_code, 201, r.content)
        return r.json()["id"]

    def responder(self, intento_id, pregunta, opciones=(), texto="", usuario=None):
        return self.cliente(usuario or self.estudiante).post(
            f"/api/intentos/{intento_id}/responder/",
            {
                "pregunta": pregunta.pk,
                "opciones": [o.pk for o in opciones],
                "texto_respuesta": texto,
            },
            format="json",
        )

    def enviar(self, intento_id, usuario=None):
        return self.cliente(usuario or self.estudiante).post(
            f"/api/intentos/{intento_id}/enviar/"
        )

    def rendir(self, *respuestas):
        """respuestas: tuplas (pregunta, [opciones], texto). Devuelve el id del intento."""
        intento_id = self.empezar()
        for pregunta, opciones, texto in respuestas:
            r = self.responder(intento_id, pregunta, opciones, texto)
            self.assertEqual(r.status_code, 200, r.content)
        self.assertEqual(self.enviar(intento_id).status_code, 200)
        return intento_id

    def respuesta(self, intento_id, pregunta):
        return RespuestaIntento.objects.get(intento_id=intento_id, pregunta=pregunta)

    def vencer(self, intento_id, segundos=60):
        Intento.objects.filter(pk=intento_id).update(
            fecha_limite=timezone.now() - timedelta(seconds=segundos)
        )

    def calificar_abierta(self, resultado, puntaje, usuario=None):
        resp = self.respuesta(resultado.intento_id, self.p_abierta)
        return self.cliente(usuario or self.docente).post(
            f"/api/resultados/{resultado.pk}/calificar/",
            {"calificaciones": [{"respuesta": resp.pk, "puntaje": puntaje}]},
            format="json",
        )

    def rendir_todo_correcto(self):
        return self.rendir(
            (self.p_unica, [self.unica_ok], ""),
            (self.p_multiple, [self.mult_1, self.mult_2], ""),
            (self.p_vf, [self.vf_v], ""),
            (self.p_abierta, [], "mi respuesta"),
        )


# =========================================================================
class IniciarIntentoTests(IntentosBase):
    def test_estudiante_inicia_intento(self):
        r = self.iniciar()
        self.assertEqual(r.status_code, 201)
        data = r.json()
        self.assertEqual(data["estado"], E.EN_PROGRESO)
        self.assertEqual(len(data["preguntas"]), 4)
        self.asignacion.refresh_from_db()
        self.assertEqual(self.asignacion.estado, AsignacionExamen.Estado.EN_PROGRESO)

    def test_nunca_se_expone_es_correcta_durante_el_intento(self):
        r = self.iniciar()
        self.assertNotIn("es_correcta", r.content.decode())
        intento_id = r.json()["id"]
        r2 = self.cliente(self.estudiante).get(f"/api/intentos/{intento_id}/")
        self.assertEqual(r2.status_code, 200)
        self.assertNotIn("es_correcta", r2.content.decode())

    def test_reiniciar_reanuda_el_mismo_intento(self):
        primero = self.empezar()
        r = self.iniciar()
        self.assertEqual(r.status_code, 200)  # no 201: no se creó uno nuevo
        self.assertEqual(r.json()["id"], primero)
        self.assertEqual(Intento.objects.filter(asignacion=self.asignacion).count(), 1)

    def test_examen_en_borrador_no_se_puede_iniciar(self):
        _, asig = self.crear_examen(estado=Examen.Estado.BORRADOR, estudiante=self.otro_estudiante)
        self.assertEqual(self.iniciar(self.otro_estudiante, asig).status_code, 400)

    def test_examen_que_aun_no_comienza(self):
        _, asig = self.crear_examen(
            inicio=timedelta(hours=1), fin=timedelta(hours=2), estudiante=self.otro_estudiante
        )
        self.assertEqual(self.iniciar(self.otro_estudiante, asig).status_code, 400)

    def test_examen_que_ya_termino(self):
        _, asig = self.crear_examen(
            inicio=timedelta(hours=-2), fin=timedelta(hours=-1), estudiante=self.otro_estudiante
        )
        self.assertEqual(self.iniciar(self.otro_estudiante, asig).status_code, 400)

    def test_asignacion_de_otro_estudiante_da_404(self):
        self.assertEqual(self.iniciar(self.otro_estudiante).status_code, 404)

    def test_docente_no_puede_rendir(self):
        self.assertEqual(self.iniciar(self.docente).status_code, 403)

    def test_sin_autenticar(self):
        r = self.cliente().post("/api/intentos/", {"asignacion": self.asignacion.pk}, format="json")
        self.assertIn(r.status_code, (401, 403))

    def test_limite_no_pasa_de_fecha_fin_del_examen(self):
        examen, asig = self.crear_examen(
            fin=timedelta(minutes=10), duracion=60, estudiante=self.otro_estudiante
        )
        intento_id = self.empezar(usuario=self.otro_estudiante, asignacion=asig)
        intento = Intento.objects.get(pk=intento_id)
        self.assertLessEqual(intento.fecha_limite, examen.fecha_fin)

    def test_intentos_agotados(self):
        self.rendir()
        self.asignacion.refresh_from_db()
        self.assertEqual(self.asignacion.estado, AsignacionExamen.Estado.COMPLETADO)
        self.assertEqual(self.iniciar().status_code, 400)

    def test_segundo_intento_si_el_examen_lo_permite(self):
        examen, asig = self.crear_examen(intentos=2, estudiante=self.otro_estudiante)
        primero = self.empezar(usuario=self.otro_estudiante, asignacion=asig)
        self.assertEqual(self.enviar(primero, self.otro_estudiante).status_code, 200)
        segundo = self.iniciar(self.otro_estudiante, asig)
        self.assertEqual(segundo.status_code, 201)
        self.assertEqual(segundo.json()["numero_intento"], 2)

    def test_queda_historial_de_estado(self):
        intento_id = self.empezar()
        self.assertTrue(
            HistorialEstado.objects.filter(
                entidad="Intento", entidad_id=str(intento_id), estado_nuevo=E.EN_PROGRESO
            ).exists()
        )


# =========================================================================
class ResponderTests(IntentosBase):
    def setUp(self):
        super().setUp()
        self.intento_id = self.empezar()

    def test_guarda_respuesta_de_opcion_unica(self):
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok])
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["guardada"])
        self.assertEqual(
            [s.opcion_id for s in self.respuesta(self.intento_id, self.p_unica).seleccion.all()],
            [self.unica_ok.pk],
        )

    def test_cambiar_respuesta_sobrescribe_sin_duplicar(self):
        self.responder(self.intento_id, self.p_unica, [self.unica_mal])
        self.responder(self.intento_id, self.p_unica, [self.unica_ok])
        self.assertEqual(
            RespuestaIntento.objects.filter(intento_id=self.intento_id, pregunta=self.p_unica).count(), 1
        )
        resp = self.respuesta(self.intento_id, self.p_unica)
        self.assertEqual([s.opcion_id for s in resp.seleccion.all()], [self.unica_ok.pk])

    def test_multiple_admite_varias_opciones(self):
        r = self.responder(self.intento_id, self.p_multiple, [self.mult_1, self.mult_2])
        self.assertEqual(r.status_code, 200)

    def test_abierta_guarda_texto(self):
        r = self.responder(self.intento_id, self.p_abierta, texto="Mi respuesta")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.respuesta(self.intento_id, self.p_abierta).texto_respuesta, "Mi respuesta")

    def test_unica_no_admite_dos_opciones(self):
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok, self.unica_mal])
        self.assertEqual(r.status_code, 400)

    def test_verdadero_falso_no_admite_dos_opciones(self):
        r = self.responder(self.intento_id, self.p_vf, [self.vf_v, self.vf_f])
        self.assertEqual(r.status_code, 400)

    def test_opcion_de_otra_pregunta(self):
        r = self.responder(self.intento_id, self.p_unica, [self.vf_v])
        self.assertEqual(r.status_code, 400)

    def test_abierta_no_admite_opciones(self):
        r = self.responder(self.intento_id, self.p_abierta, [self.unica_ok])
        self.assertEqual(r.status_code, 400)

    def test_pregunta_cerrada_no_admite_texto(self):
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok], texto="hola")
        self.assertEqual(r.status_code, 400)

    def test_pregunta_que_no_es_del_examen(self):
        r = self.responder(self.intento_id, self.p_ajena, [self.ajena_op])
        self.assertEqual(r.status_code, 400)

    def test_otro_estudiante_no_puede_responder_mi_intento(self):
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok], usuario=self.otro_estudiante)
        self.assertEqual(r.status_code, 404)

    def test_tolerancia_de_gracia_permite_responder(self):
        self.vencer(self.intento_id, segundos=2)  # dentro de los 5 s de gracia
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok])
        self.assertEqual(r.status_code, 200)

    def test_responder_tras_vencer_cierra_el_intento(self):
        self.vencer(self.intento_id, segundos=60)
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok])
        self.assertEqual(r.status_code, 400)
        self.assertEqual(Intento.objects.get(pk=self.intento_id).estado, E.EXPIRADO)
        self.assertTrue(ResultadoExamen.objects.filter(intento_id=self.intento_id).exists())

    def test_no_se_responde_un_intento_ya_enviado(self):
        self.enviar(self.intento_id)
        r = self.responder(self.intento_id, self.p_unica, [self.unica_ok])
        self.assertEqual(r.status_code, 400)


# =========================================================================
class CalificacionTests(IntentosBase):
    def test_automatica_y_abierta_queda_pendiente(self):
        intento_id = self.rendir_todo_correcto()
        res = ResultadoExamen.objects.get(intento_id=intento_id)
        self.assertEqual(res.puntaje_total, 5.0)
        self.assertEqual(res.puntaje_maximo, 6.0)
        self.assertEqual(res.nota_final, 4.2)  # 5/6 * 5 = 4.17 → 4.2
        self.assertEqual(res.estado_revision, R.PENDIENTE)
        self.assertIsNone(self.respuesta(intento_id, self.p_abierta).puntaje_obtenido)

    def test_enviar_sin_responder_da_cero_y_queda_revisado(self):
        intento_id = self.rendir()
        res = ResultadoExamen.objects.get(intento_id=intento_id)
        self.assertEqual(res.puntaje_total, 0.0)
        self.assertEqual(res.nota_final, 0.0)
        self.assertEqual(res.estado_revision, R.REVISADO)  # abierta vacía = 0, no hay pendientes
        self.assertEqual(RespuestaIntento.objects.filter(intento_id=intento_id).count(), 4)

    def test_opcion_unica_incorrecta_da_cero(self):
        intento_id = self.rendir((self.p_unica, [self.unica_mal], ""))
        resp = self.respuesta(intento_id, self.p_unica)
        self.assertEqual(resp.puntaje_obtenido, 0.0)
        self.assertFalse(resp.es_correcta)

    def test_verdadero_falso_correcto(self):
        intento_id = self.rendir((self.p_vf, [self.vf_v], ""))
        resp = self.respuesta(intento_id, self.p_vf)
        self.assertEqual(resp.puntaje_obtenido, 1.0)
        self.assertTrue(resp.es_correcta)

    def test_multiple_todas_correctas(self):
        intento_id = self.rendir((self.p_multiple, [self.mult_1, self.mult_2], ""))
        resp = self.respuesta(intento_id, self.p_multiple)
        self.assertEqual(resp.puntaje_obtenido, 2.0)
        self.assertTrue(resp.es_correcta)

    def test_multiple_parcial_es_proporcional(self):
        intento_id = self.rendir((self.p_multiple, [self.mult_1], ""))
        resp = self.respuesta(intento_id, self.p_multiple)
        self.assertEqual(resp.puntaje_obtenido, 1.0)  # 1 de 2 aciertos
        self.assertFalse(resp.es_correcta)

    def test_multiple_cada_error_resta_un_acierto(self):
        intento_id = self.rendir((self.p_multiple, [self.mult_1, self.mult_mal], ""))
        self.assertEqual(self.respuesta(intento_id, self.p_multiple).puntaje_obtenido, 0.0)

    def test_multiple_marcar_todo_no_da_puntaje_completo(self):
        intento_id = self.rendir((self.p_multiple, [self.mult_1, self.mult_2, self.mult_mal], ""))
        resp = self.respuesta(intento_id, self.p_multiple)
        self.assertEqual(resp.puntaje_obtenido, 1.0)  # (2 aciertos - 1 error) / 2
        self.assertFalse(resp.es_correcta)

    def test_enviar_es_idempotente(self):
        intento_id = self.empezar()
        self.assertEqual(self.enviar(intento_id).status_code, 200)
        self.assertEqual(self.enviar(intento_id).status_code, 200)
        self.assertEqual(ResultadoExamen.objects.filter(intento_id=intento_id).count(), 1)

    def test_enviar_tras_vencer_marca_expirado(self):
        intento_id = self.empezar()
        self.vencer(intento_id)
        self.assertEqual(self.enviar(intento_id).status_code, 200)
        self.assertEqual(Intento.objects.get(pk=intento_id).estado, E.EXPIRADO)

    def test_consultar_intento_vencido_lo_cierra(self):
        intento_id = self.empezar()
        self.vencer(intento_id)
        r = self.cliente(self.estudiante).get(f"/api/intentos/{intento_id}/")
        self.assertEqual(r.json()["estado"], E.EXPIRADO)

    def test_otro_estudiante_no_puede_enviar_mi_intento(self):
        intento_id = self.empezar()
        self.assertEqual(self.enviar(intento_id, self.otro_estudiante).status_code, 404)

    def test_resultado_queda_en_historial_de_estado(self):
        intento_id = self.rendir_todo_correcto()
        res = ResultadoExamen.objects.get(intento_id=intento_id)
        self.assertTrue(
            HistorialEstado.objects.filter(
                entidad="Resultado", entidad_id=str(res.pk), estado_nuevo=R.PENDIENTE
            ).exists()
        )


# =========================================================================
class RevisionDocenteTests(IntentosBase):
    def setUp(self):
        super().setUp()
        self.intento_id = self.rendir_todo_correcto()
        self.resultado = ResultadoExamen.objects.get(intento_id=self.intento_id)

    def test_docente_califica_la_abierta_y_queda_revisado(self):
        r = self.calificar_abierta(self.resultado, 1)
        self.assertEqual(r.status_code, 200, r.content)
        self.resultado.refresh_from_db()
        self.assertEqual(self.resultado.estado_revision, R.REVISADO)
        self.assertEqual(self.resultado.puntaje_total, 6.0)
        self.assertEqual(self.resultado.nota_final, 5.0)
        self.assertEqual(self.resultado.revisado_por, self.docente)
        self.assertIsNotNone(self.resultado.fecha_revision)

    def test_puntaje_parcial_en_abierta(self):
        self.calificar_abierta(self.resultado, 0.5)
        self.resultado.refresh_from_db()
        self.assertEqual(self.resultado.puntaje_total, 5.5)
        self.assertEqual(self.resultado.nota_final, 4.6)  # 5.5/6*5 = 4.58 → 4.6

    def test_puntaje_mayor_al_maximo_se_rechaza(self):
        self.assertEqual(self.calificar_abierta(self.resultado, 2).status_code, 400)
        self.resultado.refresh_from_db()
        self.assertEqual(self.resultado.estado_revision, R.PENDIENTE)

    def test_no_se_califica_una_pregunta_cerrada(self):
        resp = self.respuesta(self.intento_id, self.p_unica)
        r = self.cliente(self.docente).post(
            f"/api/resultados/{self.resultado.pk}/calificar/",
            {"calificaciones": [{"respuesta": resp.pk, "puntaje": 1}]},
            format="json",
        )
        self.assertEqual(r.status_code, 400)

    def test_docente_ajeno_no_puede_calificar(self):
        self.assertEqual(self.calificar_abierta(self.resultado, 1, self.otro_docente).status_code, 404)

    def test_estudiante_no_puede_calificar(self):
        self.assertEqual(self.calificar_abierta(self.resultado, 1, self.estudiante).status_code, 403)

    def test_docente_ve_el_resultado_de_su_examen(self):
        r = self.cliente(self.docente).get(f"/api/resultados/{self.resultado.pk}/")
        self.assertEqual(r.status_code, 200)

    def test_admin_ve_cualquier_resultado(self):
        r = self.cliente(self.admin).get(f"/api/resultados/{self.resultado.pk}/")
        self.assertEqual(r.status_code, 200)

    def test_docente_ajeno_no_ve_el_resultado(self):
        r = self.cliente(self.otro_docente).get(f"/api/resultados/{self.resultado.pk}/")
        self.assertEqual(r.status_code, 404)

    def test_notifica_al_estudiante_solo_cuando_queda_revisado(self):
        # Al enviar el resultado quedó pendiente → sin notificación
        self.assertFalse(
            Notificacion.objects.filter(usuario=self.estudiante, tipo="resultado_revisado").exists()
        )
        with self.captureOnCommitCallbacks(execute=True):
            self.calificar_abierta(self.resultado, 1)
        self.assertEqual(
            Notificacion.objects.filter(usuario=self.estudiante, tipo="resultado_revisado").count(), 1
        )
        # y el docente no recibe nada
        self.assertFalse(Notificacion.objects.filter(usuario=self.docente, tipo="resultado_revisado").exists())


# =========================================================================
class PrivacidadEstudianteTests(IntentosBase):
    """El estudiante no ve nota provisional ni respuestas correctas antes de tiempo."""

    def setUp(self):
        super().setUp()
        intento_id = self.rendir_todo_correcto()
        self.resultado = ResultadoExamen.objects.get(intento_id=intento_id)

    def detalle(self, usuario=None):
        return self.cliente(usuario or self.estudiante).get(f"/api/mis-resultados/{self.resultado.pk}/")

    def test_no_ve_nota_provisional(self):
        data = self.detalle().json()
        self.assertIsNone(data["nota_final"])
        self.assertIsNone(data["puntaje_total"])

    def test_pendiente_no_muestra_detalle(self):
        data = self.detalle().json()
        self.assertFalse(data["detalle_disponible"])
        self.assertIsNone(data["respuestas"])

    def test_revisado_pero_examen_abierto_sigue_sin_detalle(self):
        self.calificar_abierta(self.resultado, 1)
        data = self.detalle().json()
        self.assertEqual(data["nota_final"], 5.0)  # la nota sí se ve
        self.assertFalse(data["detalle_disponible"])
        self.assertIsNone(data["respuestas"])
        self.assertNotIn("opciones_correctas", self.detalle().content.decode())

    def test_revisado_y_examen_cerrado_muestra_correctas(self):
        self.calificar_abierta(self.resultado, 1)
        Examen.objects.filter(pk=self.examen.pk).update(estado=Examen.Estado.CERRADO)
        data = self.detalle().json()
        self.assertTrue(data["detalle_disponible"])
        self.assertEqual(len(data["respuestas"]), 4)
        self.assertTrue(all("opciones_correctas" in r for r in data["respuestas"]))

    def test_otro_estudiante_no_ve_mi_resultado(self):
        self.assertEqual(self.detalle(self.otro_estudiante).status_code, 404)

    def test_listado_mis_resultados_solo_los_propios(self):
        r = self.cliente(self.otro_estudiante).get("/api/mis-resultados/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["results"], [])

    def test_estudiante_no_accede_al_endpoint_del_docente(self):
        r = self.cliente(self.estudiante).get(f"/api/resultados/{self.resultado.pk}/")
        self.assertEqual(r.status_code, 403)
