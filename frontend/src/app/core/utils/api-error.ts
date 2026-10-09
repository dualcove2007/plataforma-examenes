import { HttpErrorResponse } from '@angular/common/http';

/**
 * El backend responde los errores como:
 *   { error: { codigo, mensaje, detalles } }
 * `detalles` es un objeto campo -> lista de mensajes cuando hay validación.
 */
export function mensajeError(err: unknown): string {
  if (!(err instanceof HttpErrorResponse)) {
    return 'Ocurrió un error inesperado.';
  }
  if (err.status === 0) {
    return 'No se pudo conectar con el servidor.';
  }

  const cuerpo = err.error?.error;
  if (!cuerpo) {
    return 'Ocurrió un error inesperado.';
  }

  const detalles = cuerpo.detalles;
  if (detalles && typeof detalles === 'object') {
    const mensajes = Object.values(detalles)
      .flat()
      .filter((m): m is string => typeof m === 'string');
    if (mensajes.length) {
      return mensajes.join(' ');
    }
  }
  return cuerpo.mensaje ?? 'Ocurrió un error inesperado.';
}
