from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound, ValidationError

from apps.exams.models import AsignacionExamen, Examen
from apps.question_banks.models import Pregunta
from apps.audit.services import registrar, registrar_transicion
from apps.notifications.services import notificar_resultado_revisado
from .models import EventoIntento, Intento, RespuestaIntento, RespuestaOpcion, ResultadoExamen

NOTA_MAXIMA = 5.0  # escala de la nota: 0 a 5.0
GRACIA_SEGUNDOS = 5  # tolerancia por latencia de red
MAX_EVENTOS = 200  # tope por intento, para que no se pueda inundar la tabla

E = Intento.Estado
T = Pregunta.Tipo
R = ResultadoExamen.Revision


def segundos_restantes(intento):
    if intento.estado != E.EN_PROGRESO:
        return 0
    return max(0, int((intento.fecha_limite - timezone.now()).total_seconds()))


def _vencido(intento):
    limite = intento.fecha_limite + timedelta(seconds=GRACIA_SEGUNDOS)
    return timezone.now() > limite


def refrescar_estado(intento):
    """Si el tiempo se acabó, cierra el intento (expirado) y lo califica."""
    if intento.estado == E.EN_PROGRESO and _vencido(intento):
        cerrar_intento(intento, E.EXPIRADO)
    return intento


def _actualizar_asignacion(asignacion):
    examen = asignacion.examen
    usados = asignacion.intentos.exclude(estado=E.ANULADO).count()
    if asignacion.intentos.filter(estado=E.EN_PROGRESO).exists():
        nuevo = AsignacionExamen.Estado.EN_PROGRESO
    elif usados >= examen.intentos_permitidos:
        nuevo = AsignacionExamen.Estado.COMPLETADO
    else:
        nuevo = AsignacionExamen.Estado.PENDIENTE
    if asignacion.estado != nuevo:
        asignacion.estado = nuevo
        asignacion.save(update_fields=["estado"])


def iniciar_intento(usuario, asignacion_id):
    asignacion = (
        AsignacionExamen.objects.select_related("examen")
        .filter(pk=asignacion_id, estudiante=usuario)
        .first()
    )
    if asignacion is None:
        raise NotFound("No tienes esa asignación.")

    # Cierra primero los intentos vencidos (fuera de la transacción de abajo)
    for viejo in asignacion.intentos.filter(estado=E.EN_PROGRESO):
        refrescar_estado(viejo)

    with transaction.atomic():
        asignacion = (
            AsignacionExamen.objects.select_for_update(of=("self",))
            .select_related("examen")
            .get(pk=asignacion.pk)
        )
        examen = asignacion.examen
        ahora = timezone.now()

        existente = asignacion.intentos.filter(estado=E.EN_PROGRESO).first()
        if existente:
            return existente, False  # reanudar el mismo intento

        if examen.estado != Examen.Estado.PUBLICADO:
            raise ValidationError("El examen no está publicado.")
        if ahora < examen.fecha_inicio:
            raise ValidationError("El examen aún no ha comenzado.")
        if ahora >= examen.fecha_fin:
            raise ValidationError("El examen ya terminó.")
        usados = asignacion.intentos.exclude(estado=E.ANULADO).count()
        if usados >= examen.intentos_permitidos:
            raise ValidationError("Ya usaste todos tus intentos.")

        limite = min(
            ahora + timedelta(minutes=examen.duracion_minutos), examen.fecha_fin
        )
        intento = Intento.objects.create(
            asignacion=asignacion,
            numero_intento=asignacion.intentos.count() + 1,
            fecha_limite=limite,
        )
        _actualizar_asignacion(asignacion)
        registrar_transicion("Intento", intento.pk, "", E.EN_PROGRESO)
        return intento, True



def responder(intento, pregunta, opciones, texto_respuesta):
    refrescar_estado(intento)
    if intento.estado != E.EN_PROGRESO:
        raise ValidationError(
            "Se acabó el tiempo: tu intento se cerró."
            if intento.estado == E.EXPIRADO
            else "El intento ya no está en progreso."
        )

    item = (
        intento.asignacion.examen.items.select_related("pregunta")
        .prefetch_related("pregunta__opciones")
        .filter(pregunta_id=pregunta)
        .first()
    )
    if item is None:
        raise ValidationError({"pregunta": "La pregunta no pertenece a este examen."})

    p = item.pregunta
    opciones = set(opciones)
    if p.tipo == T.ABIERTA:
        if opciones:
            raise ValidationError({"opciones": "Esta pregunta es abierta: responde con texto."})
    else:
        if texto_respuesta.strip():
            raise ValidationError({"texto_respuesta": "Esta pregunta no admite texto."})
        if not opciones <= {o.id for o in p.opciones.all()}:
            raise ValidationError({"opciones": "Hay opciones que no son de esta pregunta."})
        if p.tipo in (T.OPCION_UNICA, T.VERDADERO_FALSO) and len(opciones) > 1:
            raise ValidationError({"opciones": "Esta pregunta admite una sola opción."})

    with transaction.atomic():
        respuesta, _ = RespuestaIntento.objects.update_or_create(
            intento=intento,
            pregunta=p,
            defaults={
                "texto_respuesta": texto_respuesta,
                "fecha_respuesta": timezone.now(),
            },
        )
        respuesta.seleccion.all().delete()
        RespuestaOpcion.objects.bulk_create(
            [RespuestaOpcion(respuesta=respuesta, opcion_id=o) for o in opciones]
        )
    return respuesta


@transaction.atomic
def cerrar_intento(intento, estado):
    anterior = intento.estado
    intento.estado = estado
    intento.fecha_fin = min(timezone.now(), intento.fecha_limite)
    intento.save(update_fields=["estado", "fecha_fin"])
    registrar_transicion("Intento", intento.pk, anterior, estado)
    calificar(intento)
    _actualizar_asignacion(intento.asignacion)


def enviar_intento(intento):
    refrescar_estado(intento)
    if intento.estado == E.EN_PROGRESO:
        cerrar_intento(intento, E.FINALIZADO)
    elif intento.estado == E.ANULADO:
        raise ValidationError("El intento fue anulado.")
    return ResultadoExamen.objects.get(intento=intento)  # idempotente


def expirar_intentos_vencidos():
    """La usará la tarea programada (Celery) para cerrar intentos abandonados."""
    limite = timezone.now() - timedelta(seconds=GRACIA_SEGUNDOS)
    pendientes = Intento.objects.filter(
        estado=E.EN_PROGRESO, fecha_limite__lt=limite
    ).select_related("asignacion__examen")
    total = 0
    for intento in pendientes:
        cerrar_intento(intento, E.EXPIRADO)
        total += 1
    return total


# ----------------------------- Calificación -----------------------------
def _fraccion(tipo, correctas, seleccionadas):
    """Fracción del puntaje de la pregunta (0 a 1)."""
    if tipo in (T.OPCION_UNICA, T.VERDADERO_FALSO):
        return 1.0 if seleccionadas == correctas else 0.0
    # Opción múltiple: proporcional, cada error resta un acierto
    if not correctas:
        return 0.0
    aciertos = len(seleccionadas & correctas)
    errores = len(seleccionadas - correctas)
    return max(0.0, (aciertos - errores) / len(correctas))


def calificar(intento):
    examen = intento.asignacion.examen
    items = examen.items.select_related("pregunta").prefetch_related(
        "pregunta__opciones"
    )
    respuestas = {
        r.pregunta_id: r for r in intento.respuestas.prefetch_related("seleccion")
    }
    for item in items:
        pregunta = item.pregunta
        r = respuestas.get(pregunta.id) or RespuestaIntento(
            intento=intento, pregunta=pregunta
        )  # pregunta sin responder
        if pregunta.tipo == T.ABIERTA:
            if r.texto_respuesta.strip():
                r.puntaje_obtenido = None  # pendiente de revisión del docente
                r.es_correcta = None
            else:
                r.puntaje_obtenido = 0.0
                r.es_correcta = False
        else:
            correctas = {o.id for o in pregunta.opciones.all() if o.es_correcta}
            seleccionadas = (
                {s.opcion_id for s in r.seleccion.all()} if r.pk else set()
            )
            fraccion = _fraccion(pregunta.tipo, correctas, seleccionadas)
            r.puntaje_obtenido = round(item.puntaje * fraccion, 2)
            r.es_correcta = fraccion == 1.0
        r.save()
    return _recalcular(intento)


def _recalcular(intento, docente=None):
    examen = intento.asignacion.examen
    maximo = sum(i.puntaje for i in examen.items.all())
    respuestas = list(intento.respuestas.all())
    total = sum(r.puntaje_obtenido or 0 for r in respuestas)
    pendientes = sum(1 for r in respuestas if r.puntaje_obtenido is None)

    resultado, creado = ResultadoExamen.objects.get_or_create(intento=intento)
    anterior = "" if creado else resultado.estado_revision

    resultado.puntaje_total = round(total, 2)
    resultado.puntaje_maximo = round(maximo, 2)
    resultado.nota_final = round(total / maximo * NOTA_MAXIMA, 1) if maximo else 0.0

    if pendientes == 0:
        resultado.estado_revision = R.REVISADO
        if docente:
            resultado.revisado_por = docente
            resultado.fecha_revision = timezone.now()
    elif docente:
        resultado.estado_revision = R.EN_REVISION
    else:
        resultado.estado_revision = R.PENDIENTE

    resultado.save()

    if anterior != resultado.estado_revision:
        registrar_transicion(
            "Resultado",
            resultado.pk,
            anterior,
            resultado.estado_revision,
            docente,
        )

        # Notificar al estudiante únicamente cuando el resultado
        # acaba de pasar a REVISADO.
        if resultado.estado_revision == R.REVISADO:
            transaction.on_commit(
                lambda: notificar_resultado_revisado(resultado)
            )

    return resultado


@transaction.atomic
def calificar_abiertas(resultado, calificaciones, docente):
    intento = resultado.intento
    if intento.estado == E.EN_PROGRESO:
        raise ValidationError("El intento sigue en progreso.")
    maximos = {i.pregunta_id: i.puntaje for i in intento.asignacion.examen.items.all()}
    for c in calificaciones:
        r = intento.respuestas.filter(
            pk=c["respuesta"], pregunta__tipo=T.ABIERTA
        ).first()
        if r is None:
            raise ValidationError(
                {"calificaciones": f"La respuesta {c['respuesta']} no es una pregunta abierta de este intento."}
            )
        maximo = maximos[r.pregunta_id]
        if c["puntaje"] > maximo:
            raise ValidationError(
                {"calificaciones": f"El puntaje máximo de esa pregunta es {maximo}."}
            )
        r.puntaje_obtenido = c["puntaje"]
        r.es_correcta = c["puntaje"] >= maximo
        r.save(update_fields=["puntaje_obtenido", "es_correcta"])
    registrar(
        "calificar", "Resultado", resultado.pk,
        {"calificaciones": [
            {"respuesta": c["respuesta"], "puntaje": float(c["puntaje"])}
            for c in calificaciones
        ]},
        docente,
    )
    return _recalcular(intento, docente)



def registrar_evento(intento, tipo, duracion_segundos=None):
    """Guarda una señal anti-trampa. Solo mientras el intento está en progreso."""
    refrescar_estado(intento)
    if intento.estado != E.EN_PROGRESO:
        raise ValidationError("El intento ya no está en progreso.")
    if intento.eventos.count() >= MAX_EVENTOS:
        return None
    return EventoIntento.objects.create(
        intento=intento, tipo=tipo, duracion_segundos=duracion_segundos
    )