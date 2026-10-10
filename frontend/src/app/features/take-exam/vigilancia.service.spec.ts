import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { IntentosService } from './intentos.service';
import { VigilanciaIntento } from './vigilancia.service';

describe('VigilanciaIntento', () => {
  let vigilancia: VigilanciaIntento;
  const registrarEvento = vi.fn();

  function visibilidad(estado: 'hidden' | 'visible') {
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => estado });
    document.dispatchEvent(new Event('visibilitychange'));
  }

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-09T12:00:00Z'));
    registrarEvento.mockReset().mockReturnValue(of({ registrado: true }));
    TestBed.configureTestingModule({
      providers: [VigilanciaIntento, { provide: IntentosService, useValue: { registrarEvento } }],
    });
    vigilancia = TestBed.inject(VigilanciaIntento);
  });

  afterEach(() => {
    vigilancia.detener();
    visibilidad('visible');
    vi.useRealTimers();
  });

  it('registra la salida de pestaña con los segundos que estuvo fuera', () => {
    vigilancia.iniciar(7);
    visibilidad('hidden');
    vi.advanceTimersByTime(12_000);
    visibilidad('visible');

    expect(registrarEvento).toHaveBeenCalledExactlyOnceWith(7, 'salida_pestana', 12);
  });

  it('no registra nada mientras sigue oculta: solo al volver', () => {
    vigilancia.iniciar(7);
    visibilidad('hidden');
    vi.advanceTimersByTime(30_000);

    expect(registrarEvento).not.toHaveBeenCalled();
  });

  it('ignora parpadeos de menos de un segundo', () => {
    vigilancia.iniciar(7);
    visibilidad('hidden');
    vi.advanceTimersByTime(300);
    visibilidad('visible');

    expect(registrarEvento).not.toHaveBeenCalled();
  });

  it('varias salidas se registran por separado', () => {
    vigilancia.iniciar(7);
    visibilidad('hidden');
    vi.advanceTimersByTime(5_000);
    visibilidad('visible');
    visibilidad('hidden');
    vi.advanceTimersByTime(9_000);
    visibilidad('visible');

    expect(registrarEvento).toHaveBeenCalledTimes(2);
    expect(registrarEvento).toHaveBeenNthCalledWith(1, 7, 'salida_pestana', 5);
    expect(registrarEvento).toHaveBeenNthCalledWith(2, 7, 'salida_pestana', 9);
  });

  it('registra cuando el estudiante pega texto', () => {
    vigilancia.iniciar(7);
    document.dispatchEvent(new Event('paste'));

    expect(registrarEvento).toHaveBeenCalledExactlyOnceWith(7, 'pegado', undefined);
  });

  it('no hace nada antes de iniciar', () => {
    visibilidad('hidden');
    vi.advanceTimersByTime(5_000);
    visibilidad('visible');
    document.dispatchEvent(new Event('paste'));

    expect(registrarEvento).not.toHaveBeenCalled();
  });

  it('después de detener ya no registra', () => {
    vigilancia.iniciar(7);
    vigilancia.detener();
    visibilidad('hidden');
    vi.advanceTimersByTime(5_000);
    visibilidad('visible');
    document.dispatchEvent(new Event('paste'));

    expect(registrarEvento).not.toHaveBeenCalled();
  });

  it('detener mientras estaba oculta descarta esa salida', () => {
    vigilancia.iniciar(7);
    visibilidad('hidden');
    vi.advanceTimersByTime(5_000);
    vigilancia.detener();
    visibilidad('visible');

    expect(registrarEvento).not.toHaveBeenCalled();
  });

  it('iniciar dos veces no duplica los avisos', () => {
    vigilancia.iniciar(7);
    vigilancia.iniciar(7);
    document.dispatchEvent(new Event('paste'));

    expect(registrarEvento).toHaveBeenCalledTimes(1);
  });

  it('si el backend falla, no rompe nada', () => {
    registrarEvento.mockReturnValue(throwError(() => new Error('sin red')));
    vigilancia.iniciar(7);

    expect(() => document.dispatchEvent(new Event('paste'))).not.toThrow();
  });
});