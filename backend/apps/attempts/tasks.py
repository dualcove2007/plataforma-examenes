from celery import shared_task

from .services import expirar_intentos_vencidos


@shared_task(name="attempts.expirar_intentos_vencidos")
def expirar_intentos_vencidos_task():
    return expirar_intentos_vencidos()