import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';

import { mensajeError } from './api-error';

describe('mensajeError', () => {
  it('devuelve un mensaje genérico si no es un HttpErrorResponse', () => {
    expect(mensajeError(new Error('x'))).toBe('Ocurrió un error inesperado.');
  });

  it('avisa cuando no hay conexión (status 0)', () => {
    const err = new HttpErrorResponse({ status: 0 });
    expect(mensajeError(err)).toBe('No se pudo conectar con el servidor.');
  });

  it('usa el mensaje del backend', () => {
    const err = new HttpErrorResponse({
      status: 400,
      error: { error: { codigo: 'x', mensaje: 'Algo falló.' } },
    });
    expect(mensajeError(err)).toBe('Algo falló.');
  });

  it('une los detalles de validación cuando vienen por campo', () => {
    const err = new HttpErrorResponse({
      status: 400,
      error: {
        error: {
          mensaje: 'Datos inválidos.',
          detalles: { email: ['Correo inválido.'], nombre: ['Requerido.'] },
        },
      },
    });
    expect(mensajeError(err)).toBe('Correo inválido. Requerido.');
  });

  it('lee los detalles aunque lleguen como lista', () => {
    const err = new HttpErrorResponse({
      status: 400,
      error: { error: { mensaje: 'Error.', detalles: ['Solo puedes eliminar leídas.'] } },
    });
    expect(mensajeError(err)).toBe('Solo puedes eliminar leídas.');
  });

  it('cae al mensaje genérico si el cuerpo no tiene el formato esperado', () => {
    const err = new HttpErrorResponse({ status: 500, error: 'Internal Server Error' });
    expect(mensajeError(err)).toBe('Ocurrió un error inesperado.');
  });
});