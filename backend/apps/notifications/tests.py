"""Pruebas del módulo notifications: eventos, aislamiento por usuario y lectura.

Ubicación: backend/apps/notifications/tests.py
Ejecutar:  python -m pytest apps/notifications
"""
from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.authentication.models import Usuario
from apps.exams.models import AsignacionExamen, Examen, ExamenPregunta
from apps.notifications.models import Notificacion
from apps.question_banks.models import BancoPreguntas, Materia, Pregunta

T = Notificacion.Tipo


class NotificacionesBase(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.otro_estudiante = Usuario.objects.create_user(
            "otro.est@demo.com", "Otro Estudiante", "Demo12345*", rol=cls.estudiante.rol
        )
        cls.materia = Materia.objects.create(nombre="Redes")
        banco = BancoPreguntas.objects.create(
            materia=cls.materia, docente=cls.docente, titulo="Banco"
        )
        cls.pregunta = Pregunta.objects.create(
            banco=banco, enunciado="P", tipo=Pregunta.Tipo.ABIERTA, puntaje=1
        )

    def cliente(self, usuario=None):
        c = APIClient()
        if usuario:
            c.force_authenticate(usuario)
        return c

    def crear_examen(self, estado=Examen.Estado.BORRADOR, titulo="Parcial de Redes"):
        ahora = timezone.now()
        examen = Examen.objects.create(
            docente=self.docente, materia=self.materia, titulo=titulo,
            fecha_inicio=ahora - timedelta(hours=1), fecha_fin=ahora + timedelta(days=1),
            duracion_minutos=30, estado=estado,
        )
        ExamenPregunta.objects.create(examen=examen, pregunta=self.pregunta, orden=1, puntaje=1)
        return examen

    def notificar(self, usuario, tipo=T.EXAMEN_PUBLICADO, leida=False, titulo="Título"):
        return Notificacion.objects.create(
            usuario=usuario, tipo=tipo, titulo=titulo, mensaje="Mensaje", leida=leida
        )

    def accion_docente(self, url, data=None):
        return self.cliente(self.docente).post(url, data or {}, format="json")


# =========================================================================
class EventosDeNotificacionTests(NotificacionesBase):
    """Se generan al publicar o al asignar a un examen ya publicado."""

    def test_publicar_notifica_a_los_estudiantes_asignados(self):
        examen = self.crear_examen()
        AsignacionExamen.objects.create(examen=examen, estudiante=self.estudiante)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.accion_docente(f"/api/examenes/{examen.pk}/publicar/")
        self.assertEqual(r.status_code, 200, r.content)
        n = Notificacion.objects.get(usuario=self.estudiante, tipo=T.EXAMEN_PUBLICADO)
        self.assertEqual(n.entidad, "Examen")
        self.assertEqual(n.entidad_id, str(examen.pk))
        self.assertIn(examen.titulo, n.mensaje)
        self.assertFalse(n.leida)

    def test_publicar_no_notifica_a_quienes_no_estan_asignados(self):
        examen = self.crear_examen()
        AsignacionExamen.objects.create(examen=examen, estudiante=self.estudiante)
        with self.captureOnCommitCallbacks(execute=True):
            self.accion_docente(f"/api/examenes/{examen.pk}/publicar/")
        self.assertFalse(Notificacion.objects.filter(usuario=self.otro_estudiante).exists())
        self.assertFalse(Notificacion.objects.filter(usuario=self.docente).exists())

    def test_publicar_fallido_no_notifica(self):
        examen = self.crear_examen()
        examen.items.all().delete()  # sin preguntas → no se puede publicar
        AsignacionExamen.objects.create(examen=examen, estudiante=self.estudiante)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.accion_docente(f"/api/examenes/{examen.pk}/publicar/")
        self.assertEqual(r.status_code, 400)
        self.assertEqual(Notificacion.objects.count(), 0)

    def test_asignar_en_borrador_no_notifica(self):
        examen = self.crear_examen()
        with self.captureOnCommitCallbacks(execute=True):
            self.accion_docente(f"/api/examenes/{examen.pk}/asignar/", {"estudiantes": [self.estudiante.pk]})
        self.assertEqual(Notificacion.objects.count(), 0)

    def test_asignar_en_examen_publicado_notifica_a_los_nuevos(self):
        examen = self.crear_examen(estado=Examen.Estado.PUBLICADO)
        with self.captureOnCommitCallbacks(execute=True):
            self.accion_docente(f"/api/examenes/{examen.pk}/asignar/", {"estudiantes": [self.estudiante.pk]})
        n = Notificacion.objects.get(usuario=self.estudiante)
        self.assertEqual(n.tipo, T.EXAMEN_ASIGNADO)
        self.assertEqual(n.entidad_id, str(examen.pk))

    def test_reasignar_no_duplica_la_notificacion(self):
        examen = self.crear_examen(estado=Examen.Estado.PUBLICADO)
        url = f"/api/examenes/{examen.pk}/asignar/"
        for _ in range(2):
            with self.captureOnCommitCallbacks(execute=True):
                self.accion_docente(url, {"estudiantes": [self.estudiante.pk]})
        self.assertEqual(Notificacion.objects.filter(usuario=self.estudiante).count(), 1)


# =========================================================================
class ListadoDeNotificacionesTests(NotificacionesBase):
    def listar(self, usuario, **params):
        r = self.cliente(usuario).get("/api/notificaciones/", params)
        self.assertEqual(r.status_code, 200)
        return r.json()["results"]

    def test_cada_usuario_ve_solo_las_suyas(self):
        mia = self.notificar(self.estudiante)
        self.notificar(self.otro_estudiante)
        self.assertEqual([n["id"] for n in self.listar(self.estudiante)], [mia.pk])

    def test_sin_autenticar(self):
        self.assertIn(self.cliente().get("/api/notificaciones/").status_code, (401, 403))

    def test_cualquier_rol_autenticado_puede_consultar(self):
        self.assertEqual(self.cliente(self.docente).get("/api/notificaciones/").status_code, 200)

    def test_detalle_de_una_ajena_da_404(self):
        ajena = self.notificar(self.otro_estudiante)
        r = self.cliente(self.estudiante).get(f"/api/notificaciones/{ajena.pk}/")
        self.assertEqual(r.status_code, 404)

    def test_filtra_por_leida(self):
        self.notificar(self.estudiante, leida=True)
        pendiente = self.notificar(self.estudiante, leida=False)
        self.assertEqual([n["id"] for n in self.listar(self.estudiante, leida="false")], [pendiente.pk])

    def test_filtra_por_tipo(self):
        self.notificar(self.estudiante, tipo=T.EXAMEN_PUBLICADO)
        resultado = self.notificar(self.estudiante, tipo=T.RESULTADO_REVISADO)
        self.assertEqual(
            [n["id"] for n in self.listar(self.estudiante, tipo=T.RESULTADO_REVISADO)], [resultado.pk]
        )

    def test_busca_por_titulo(self):
        buscada = self.notificar(self.estudiante, titulo="Examen de Física")
        self.notificar(self.estudiante, titulo="Otra cosa")
        self.assertEqual([n["id"] for n in self.listar(self.estudiante, search="Física")], [buscada.pk])

    def test_orden_mas_recientes_primero(self):
        primera = self.notificar(self.estudiante)
        segunda = self.notificar(self.estudiante)
        self.assertEqual([n["id"] for n in self.listar(self.estudiante)], [segunda.pk, primera.pk])


# =========================================================================
class LecturaDeNotificacionesTests(NotificacionesBase):
    def test_contador_de_no_leidas(self):
        self.notificar(self.estudiante)
        self.notificar(self.estudiante)
        self.notificar(self.estudiante, leida=True)
        self.notificar(self.otro_estudiante)  # no cuenta
        r = self.cliente(self.estudiante).get("/api/notificaciones/no-leidas/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json(), {"no_leidas": 2})

    def test_marcar_una_como_leida(self):
        n = self.notificar(self.estudiante)
        r = self.cliente(self.estudiante).post(f"/api/notificaciones/{n.pk}/marcar-leida/")
        self.assertEqual(r.status_code, 200)
        n.refresh_from_db()
        self.assertTrue(n.leida)
        self.assertIsNotNone(n.fecha_lectura)

    def test_marcar_leida_dos_veces_conserva_la_primera_fecha(self):
        n = self.notificar(self.estudiante)
        c = self.cliente(self.estudiante)
        c.post(f"/api/notificaciones/{n.pk}/marcar-leida/")
        n.refresh_from_db()
        primera = n.fecha_lectura
        c.post(f"/api/notificaciones/{n.pk}/marcar-leida/")
        n.refresh_from_db()
        self.assertEqual(n.fecha_lectura, primera)

    def test_no_se_marca_una_ajena(self):
        ajena = self.notificar(self.otro_estudiante)
        r = self.cliente(self.estudiante).post(f"/api/notificaciones/{ajena.pk}/marcar-leida/")
        self.assertEqual(r.status_code, 404)
        ajena.refresh_from_db()
        self.assertFalse(ajena.leida)

    def test_marcar_todas_solo_afecta_las_propias(self):
        self.notificar(self.estudiante)
        self.notificar(self.estudiante)
        ajena = self.notificar(self.otro_estudiante)
        r = self.cliente(self.estudiante).post("/api/notificaciones/marcar-todas/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json(), {"marcadas": 2})
        self.assertEqual(Notificacion.objects.filter(usuario=self.estudiante, leida=False).count(), 0)
        ajena.refresh_from_db()
        self.assertFalse(ajena.leida)

    def test_marcar_todas_sin_pendientes(self):
        r = self.cliente(self.estudiante).post("/api/notificaciones/marcar-todas/")
        self.assertEqual(r.json(), {"marcadas": 0})

    def test_acciones_requieren_autenticacion(self):
        n = self.notificar(self.estudiante)
        c = self.cliente()
        self.assertIn(c.post(f"/api/notificaciones/{n.pk}/marcar-leida/").status_code, (401, 403))
        self.assertIn(c.post("/api/notificaciones/marcar-todas/").status_code, (401, 403))
        self.assertIn(c.get("/api/notificaciones/no-leidas/").status_code, (401, 403))