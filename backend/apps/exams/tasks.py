from celery import shared_task

from .services import cerrar_examenes_vencidos


@shared_task(name="exams.cerrar_examenes_vencidos")
def cerrar_examenes_vencidos_task():
    return cerrar_examenes_vencidos()