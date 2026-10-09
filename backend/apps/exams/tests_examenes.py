"""Pruebas del módulo exams: CRUD, preguntas, transiciones de estado, asignaciones.

Ubicación: backend/apps/exams/tests_examenes.py
Ejecutar:  python -m pytest apps/exams/tests_examenes.py
"""
from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.audit.models import HistorialEstado
from apps.authentication.models import Usuario
from apps.exams.models import AsignacionExamen, Examen, ExamenPregunta
from apps.question_banks.models import BancoPreguntas, Materia, Pregunta

E = Examen.Estado


class ExamenesBase(TestCase):
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
        cls.est_inactivo = Usuario.objects.create_user(
            "inactivo@demo.com", "Inactivo", "Demo12345*", rol=cls.estudiante.rol, activo=False
        )

        cls.materia = Materia.objects.create(nombre="Redes")
        cls.otra_materia = Materia.objects.create(nombre="Bases de datos")
        banco = BancoPreguntas.objects.create(
            materia=cls.materia, docente=cls.docente, titulo="Banco"
        )
        banco_otra_materia = BancoPreguntas.objects.create(
            materia=cls.otra_materia, docente=cls.docente, titulo="Banco BD"
        )
        banco_ajeno = BancoPreguntas.objects.create(
            materia=cls.materia, docente=cls.otro_docente, titulo="Banco ajeno"
        )

        def pregunta(b, enunciado, puntaje=2, activo=True):
            return Pregunta.objects.create(
                banco=b, enunciado=enunciado, tipo=Pregunta.Tipo.ABIERTA,
                puntaje=puntaje, activo=activo,
            )

        cls.p1 = pregunta(banco, "Pregunta 1", puntaje=2)
        cls.p2 = pregunta(banco, "Pregunta 2", puntaje=3)
        cls.p_inactiva = pregunta(banco, "Inactiva", activo=False)
        cls.p_otra_materia = pregunta(banco_otra_materia, "Otra materia")
        cls.p_ajena = pregunta(banco_ajeno, "De otro docente")

    # ------------------------------ helpers ------------------------------
    def cliente(self, usuario=None):
        c = APIClient()
        if usuario:
            c.force_authenticate(usuario)
        return c

    def crear_examen(
        self, docente=None, estado=E.BORRADOR, con_pregunta=True,
        inicio=timedelta(hours=-1), fin=timedelta(days=1), titulo="Parcial",
    ):
        ahora = timezone.now()
        examen = Examen.objects.create(
            docente=docente or self.docente, materia=self.materia, titulo=titulo,
            fecha_inicio=ahora + inicio, fecha_fin=ahora + fin,
            duracion_minutos=30, estado=estado,
        )
        if con_pregunta:
            ExamenPregunta.objects.create(examen=examen, pregunta=self.p1, orden=1, puntaje=2)
        return examen

    def payload(self, **extra):
        ahora = timezone.now()
        data = {
            "materia": self.materia.pk,
            "titulo": "Nuevo examen",
            "descripcion": "desc",
            "fecha_inicio": (ahora + timedelta(hours=1)).isoformat(),
            "fecha_fin": (ahora + timedelta(hours=3)).isoformat(),
            "duracion_minutos": 30,
            "intentos_permitidos": 1,
        }
        data.update(extra)
        return data

    def post(self, url, data=None, usuario=None):
        return self.cliente(usuario or self.docente).post(url, data or {}, format="json")


# =========================================================================
class ExamenCrudTests(ExamenesBase):
    def test_docente_crea_examen_en_borrador(self):
        r = self.post("/api/examenes/", self.payload())
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(r.json()["estado"], E.BORRADOR)
        self.assertEqual(r.json()["docente"], self.docente.pk)

    def test_no_se_puede_forzar_estado_ni_docente(self):
        r = self.post(
            "/api/examenes/",
            self.payload(estado=E.PUBLICADO, docente=self.otro_docente.pk),
        )
        self.assertEqual(r.status_code, 201)
        examen = Examen.objects.get(pk=r.json()["id"])
        self.assertEqual(examen.estado, E.BORRADOR)
        self.assertEqual(examen.docente, self.docente)

    def test_fecha_fin_debe_ser_posterior_al_inicio(self):
        ahora = timezone.now()
        r = self.post(
            "/api/examenes/",
            self.payload(
                fecha_inicio=(ahora + timedelta(hours=3)).isoformat(),
                fecha_fin=(ahora + timedelta(hours=1)).isoformat(),
            ),
        )
        self.assertEqual(r.status_code, 400)

    def test_duracion_fuera_de_rango(self):
        self.assertEqual(self.post("/api/examenes/", self.payload(duracion_minutos=0)).status_code, 400)
        self.assertEqual(self.post("/api/examenes/", self.payload(duracion_minutos=601)).status_code, 400)

    def test_intentos_fuera_de_rango(self):
        self.assertEqual(self.post("/api/examenes/", self.payload(intentos_permitidos=0)).status_code, 400)
        self.assertEqual(self.post("/api/examenes/", self.payload(intentos_permitidos=11)).status_code, 400)

    def test_estudiante_no_gestiona_examenes(self):
        self.assertEqual(self.post("/api/examenes/", self.payload(), self.estudiante).status_code, 403)
        self.assertEqual(self.cliente(self.estudiante).get("/api/examenes/").status_code, 403)

    def test_admin_no_tiene_permiso_de_gestion(self):
        self.assertEqual(self.cliente(self.admin).get("/api/examenes/").status_code, 403)

    def test_sin_autenticar(self):
        self.assertIn(self.cliente().get("/api/examenes/").status_code, (401, 403))

    def test_docente_solo_lista_sus_examenes(self):
        mio = self.crear_examen(titulo="Mío")
        self.crear_examen(docente=self.otro_docente, titulo="Ajeno")
        r = self.cliente(self.docente).get("/api/examenes/")
        self.assertEqual([e["id"] for e in r.json()["results"]], [mio.pk])

    def test_examen_ajeno_da_404(self):
        ajeno = self.crear_examen(docente=self.otro_docente)
        self.assertEqual(self.cliente(self.docente).get(f"/api/examenes/{ajeno.pk}/").status_code, 404)

    def test_detalle_incluye_preguntas_y_totales(self):
        examen = self.crear_examen()
        ExamenPregunta.objects.create(examen=examen, pregunta=self.p2, orden=2, puntaje=3)
        data = self.cliente(self.docente).get(f"/api/examenes/{examen.pk}/").json()
        self.assertEqual(data["total_preguntas"], 2)
        self.assertEqual(data["puntaje_total"], 5.0)
        self.assertEqual(len(data["preguntas"]), 2)

    def test_editar_borrador(self):
        examen = self.crear_examen()
        r = self.cliente(self.docente).patch(
            f"/api/examenes/{examen.pk}/", {"titulo": "Editado"}, format="json"
        )
        self.assertEqual(r.status_code, 200)
        examen.refresh_from_db()
        self.assertEqual(examen.titulo, "Editado")

    def test_no_se_edita_un_examen_publicado(self):
        examen = self.crear_examen(estado=E.PUBLICADO)
        r = self.cliente(self.docente).patch(
            f"/api/examenes/{examen.pk}/", {"titulo": "Editado"}, format="json"
        )
        self.assertEqual(r.status_code, 400)

    def test_elimina_borrador(self):
        examen = self.crear_examen(con_pregunta=False)
        self.assertEqual(self.cliente(self.docente).delete(f"/api/examenes/{examen.pk}/").status_code, 204)
        self.assertFalse(Examen.objects.filter(pk=examen.pk).exists())

    def test_no_se_elimina_un_examen_publicado(self):
        examen = self.crear_examen(estado=E.PUBLICADO)
        self.assertEqual(self.cliente(self.docente).delete(f"/api/examenes/{examen.pk}/").status_code, 400)
        self.assertTrue(Examen.objects.filter(pk=examen.pk).exists())


# =========================================================================
class PreguntasDelExamenTests(ExamenesBase):
    def setUp(self):
        self.examen = self.crear_examen(con_pregunta=False)
        self.url_add = f"/api/examenes/{self.examen.pk}/agregar-pregunta/"
        self.url_del = f"/api/examenes/{self.examen.pk}/quitar-pregunta/"

    def test_agrega_con_puntaje_por_defecto_de_la_pregunta(self):
        r = self.post(self.url_add, {"pregunta": self.p1.pk})
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(r.json()["puntaje"], 2.0)
        self.assertEqual(r.json()["orden"], 1)

    def test_agrega_con_puntaje_personalizado_y_orden_incremental(self):
        self.post(self.url_add, {"pregunta": self.p1.pk})
        r = self.post(self.url_add, {"pregunta": self.p2.pk, "puntaje": 5})
        self.assertEqual(r.json()["puntaje"], 5.0)
        self.assertEqual(r.json()["orden"], 2)

    def test_pregunta_repetida(self):
        self.post(self.url_add, {"pregunta": self.p1.pk})
        self.assertEqual(self.post(self.url_add, {"pregunta": self.p1.pk}).status_code, 400)

    def test_pregunta_inactiva(self):
        self.assertEqual(self.post(self.url_add, {"pregunta": self.p_inactiva.pk}).status_code, 400)

    def test_pregunta_de_otra_materia(self):
        self.assertEqual(self.post(self.url_add, {"pregunta": self.p_otra_materia.pk}).status_code, 400)

    def test_pregunta_de_otro_docente(self):
        self.assertEqual(self.post(self.url_add, {"pregunta": self.p_ajena.pk}).status_code, 400)

    def test_no_se_agregan_preguntas_a_un_examen_publicado(self):
        publicado = self.crear_examen(estado=E.PUBLICADO, con_pregunta=False)
        r = self.post(f"/api/examenes/{publicado.pk}/agregar-pregunta/", {"pregunta": self.p1.pk})
        self.assertEqual(r.status_code, 400)

    def test_docente_ajeno_no_puede_agregar(self):
        r = self.post(self.url_add, {"pregunta": self.p1.pk}, self.otro_docente)
        self.assertEqual(r.status_code, 404)

    def test_quita_una_pregunta(self):
        self.post(self.url_add, {"pregunta": self.p1.pk})
        self.assertEqual(self.post(self.url_del, {"pregunta": self.p1.pk}).status_code, 204)
        self.assertFalse(self.examen.items.exists())

    def test_quitar_una_pregunta_que_no_esta(self):
        self.assertEqual(self.post(self.url_del, {"pregunta": self.p1.pk}).status_code, 400)

    def test_no_se_quitan_preguntas_de_un_examen_publicado(self):
        publicado = self.crear_examen(estado=E.PUBLICADO)
        r = self.post(f"/api/examenes/{publicado.pk}/quitar-pregunta/", {"pregunta": self.p1.pk})
        self.assertEqual(r.status_code, 400)


# =========================================================================
class EstadosDelExamenTests(ExamenesBase):
    def cambiar(self, examen, accion, usuario=None):
        return self.post(f"/api/examenes/{examen.pk}/{accion}/", usuario=usuario)

    def test_publicar_con_preguntas(self):
        examen = self.crear_examen()
        r = self.cambiar(examen, "publicar")
        self.assertEqual(r.status_code, 200, r.content)
        self.assertEqual(r.json()["estado"], E.PUBLICADO)
        examen.refresh_from_db()
        self.assertEqual(examen.estado, E.PUBLICADO)

    def test_publicar_sin_preguntas_se_rechaza(self):
        examen = self.crear_examen(con_pregunta=False)
        self.assertEqual(self.cambiar(examen, "publicar").status_code, 400)
        examen.refresh_from_db()
        self.assertEqual(examen.estado, E.BORRADOR)

    def test_publicar_con_fecha_fin_vencida_se_rechaza(self):
        examen = self.crear_examen(inicio=timedelta(days=-2), fin=timedelta(days=-1))
        self.assertEqual(self.cambiar(examen, "publicar").status_code, 400)

    def test_ciclo_completo_borrador_publicado_cerrado_archivado(self):
        examen = self.crear_examen()
        for accion, esperado in [("publicar", E.PUBLICADO), ("cerrar", E.CERRADO), ("archivar", E.ARCHIVADO)]:
            r = self.cambiar(examen, accion)
            self.assertEqual(r.status_code, 200, f"{accion}: {r.content}")
            self.assertEqual(r.json()["estado"], esperado)

    def test_borrador_se_puede_archivar(self):
        self.assertEqual(self.cambiar(self.crear_examen(), "archivar").status_code, 200)

    def test_transiciones_invalidas(self):
        borrador = self.crear_examen()
        self.assertEqual(self.cambiar(borrador, "cerrar").status_code, 400)  # borrador → cerrado
        publicado = self.crear_examen(estado=E.PUBLICADO)
        self.assertEqual(self.cambiar(publicado, "archivar").status_code, 400)  # publicado → archivado
        self.assertEqual(self.cambiar(publicado, "publicar").status_code, 400)  # publicado → publicado
        archivado = self.crear_examen(estado=E.ARCHIVADO)
        self.assertEqual(self.cambiar(archivado, "publicar").status_code, 400)  # archivado es final

    def test_docente_ajeno_no_cambia_estados(self):
        examen = self.crear_examen()
        self.assertEqual(self.cambiar(examen, "publicar", self.otro_docente).status_code, 404)

    def test_estudiante_no_cambia_estados(self):
        examen = self.crear_examen()
        self.assertEqual(self.cambiar(examen, "publicar", self.estudiante).status_code, 403)

    def test_queda_historial_de_estado(self):
        examen = self.crear_examen()
        self.cambiar(examen, "publicar")
        self.assertTrue(
            HistorialEstado.objects.filter(
                entidad="Examen", entidad_id=str(examen.pk),
                estado_anterior=E.BORRADOR, estado_nuevo=E.PUBLICADO,
            ).exists()
        )


# =========================================================================
class AsignacionesTests(ExamenesBase):
    def setUp(self):
        self.examen = self.crear_examen()
        self.url = f"/api/examenes/{self.examen.pk}/asignar/"

    def test_asigna_estudiantes(self):
        r = self.post(self.url, {"estudiantes": [self.estudiante.pk, self.otro_estudiante.pk]})
        self.assertEqual(r.status_code, 200, r.content)
        self.assertEqual(r.json(), {"asignados": 2, "ya_asignados": 0})
        self.assertEqual(self.examen.asignaciones.count(), 2)

    def test_asignar_es_idempotente(self):
        self.post(self.url, {"estudiantes": [self.estudiante.pk]})
        r = self.post(self.url, {"estudiantes": [self.estudiante.pk, self.otro_estudiante.pk]})
        self.assertEqual(r.json(), {"asignados": 1, "ya_asignados": 1})
        self.assertEqual(self.examen.asignaciones.count(), 2)

    def test_no_se_asigna_a_un_docente(self):
        r = self.post(self.url, {"estudiantes": [self.otro_docente.pk]})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.examen.asignaciones.count(), 0)

    def test_no_se_asigna_a_un_estudiante_inactivo(self):
        self.assertEqual(self.post(self.url, {"estudiantes": [self.est_inactivo.pk]}).status_code, 400)

    def test_un_invalido_cancela_toda_la_asignacion(self):
        r = self.post(self.url, {"estudiantes": [self.estudiante.pk, self.otro_docente.pk]})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.examen.asignaciones.count(), 0)

    def test_lista_vacia_se_rechaza(self):
        self.assertEqual(self.post(self.url, {"estudiantes": []}).status_code, 400)

    def test_se_puede_asignar_en_examen_publicado(self):
        publicado = self.crear_examen(estado=E.PUBLICADO)
        r = self.post(f"/api/examenes/{publicado.pk}/asignar/", {"estudiantes": [self.estudiante.pk]})
        self.assertEqual(r.status_code, 200)

    def test_no_se_asigna_en_examen_cerrado_ni_archivado(self):
        for estado in (E.CERRADO, E.ARCHIVADO):
            examen = self.crear_examen(estado=estado)
            r = self.post(f"/api/examenes/{examen.pk}/asignar/", {"estudiantes": [self.estudiante.pk]})
            self.assertEqual(r.status_code, 400, estado)

    def test_docente_ajeno_no_asigna(self):
        r = self.post(self.url, {"estudiantes": [self.estudiante.pk]}, self.otro_docente)
        self.assertEqual(r.status_code, 404)

    def test_estudiante_no_asigna(self):
        r = self.post(self.url, {"estudiantes": [self.estudiante.pk]}, self.estudiante)
        self.assertEqual(r.status_code, 403)

    def test_lista_las_asignaciones_del_examen(self):
        self.post(self.url, {"estudiantes": [self.estudiante.pk]})
        r = self.cliente(self.docente).get(f"/api/examenes/{self.examen.pk}/asignaciones/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual([a["estudiante"] for a in r.json()], [self.estudiante.pk])

    def test_asignar_queda_en_auditoria(self):
        from apps.audit.models import Auditoria

        self.post(self.url, {"estudiantes": [self.estudiante.pk]})
        self.assertTrue(
            Auditoria.objects.filter(
                accion="asignar", entidad="Examen", entidad_id=str(self.examen.pk)
            ).exists()
        )


# =========================================================================
class MisExamenesTests(ExamenesBase):
    def asignar(self, examen, estudiante=None):
        return AsignacionExamen.objects.create(examen=examen, estudiante=estudiante or self.estudiante)

    def ids_examenes(self, usuario=None):
        r = self.cliente(usuario or self.estudiante).get("/api/mis-examenes/")
        self.assertEqual(r.status_code, 200)
        return {a["examen"] for a in r.json()["results"]}

    def test_ve_examenes_publicados_y_cerrados_asignados(self):
        publicado = self.crear_examen(estado=E.PUBLICADO)
        cerrado = self.crear_examen(estado=E.CERRADO)
        self.asignar(publicado)
        self.asignar(cerrado)
        self.assertEqual(self.ids_examenes(), {publicado.pk, cerrado.pk})

    def test_no_ve_borradores_ni_archivados(self):
        borrador = self.crear_examen(estado=E.BORRADOR)
        archivado = self.crear_examen(estado=E.ARCHIVADO)
        self.asignar(borrador)
        self.asignar(archivado)
        self.assertEqual(self.ids_examenes(), set())

    def test_no_ve_examenes_de_otros_estudiantes(self):
        examen = self.crear_examen(estado=E.PUBLICADO)
        self.asignar(examen, self.otro_estudiante)
        self.assertEqual(self.ids_examenes(), set())

    def test_no_ve_examenes_publicados_sin_asignar(self):
        self.crear_examen(estado=E.PUBLICADO)
        self.assertEqual(self.ids_examenes(), set())

    def test_incluye_total_de_preguntas(self):
        examen = self.crear_examen(estado=E.PUBLICADO)
        self.asignar(examen)
        r = self.cliente(self.estudiante).get("/api/mis-examenes/")
        self.assertEqual(r.json()["results"][0]["total_preguntas"], 1)

    def test_docente_no_accede(self):
        self.assertEqual(self.cliente(self.docente).get("/api/mis-examenes/").status_code, 403)

    def test_sin_autenticar(self):
        self.assertIn(self.cliente().get("/api/mis-examenes/").status_code, (401, 403))