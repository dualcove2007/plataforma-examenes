import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { Auditoria } from './auditoria';
import { AuditoriaService } from './auditoria.service';

const registro = (id: number) => ({
  id,
  usuario_nombre: 'Admin Demo',
  accion: 'crear',
  entidad: 'Examen',
  entidad_id: String(id),
  ip_address: '127.0.0.1',
  fecha: '2026-10-09T12:00:00Z',
  detalle: {},
});

const pagina = (n: number, count = n) => ({
  count,
  next: null,
  previous: null,
  results: Array.from({ length: n }, (_, i) => registro(i + 1)),
});

describe('Auditoria (componente)', () => {
  const listar = vi.fn();

  function crear() {
    const fixture = TestBed.createComponent(Auditoria);
    fixture.detectChanges();
    const el: HTMLElement = fixture.nativeElement;
    return {
      fixture,
      el,
      filas: () => el.querySelectorAll('tbody tr'),
      boton: (texto: string) =>
        Array.from(el.querySelectorAll('button')).find((b) => b.textContent?.trim() === texto)!,
    };
  }

  beforeEach(() => {
    listar.mockReset().mockReturnValue(of(pagina(2)));
    TestBed.configureTestingModule({
      providers: [{ provide: AuditoriaService, useValue: { listar } }],
    });
  });

  it('al abrir carga la pestaña de acciones, página 1, más recientes primero', () => {
    const { filas } = crear();

    expect(listar).toHaveBeenCalledExactlyOnceWith('auditoria', {
      page: 1,
      search: '',
      desde: '',
      hasta: '',
      ordering: '-fecha',
    });
    expect(filas().length).toBe(2);
  });

  it('muestra un aviso cuando no hay registros', () => {
    listar.mockReturnValue(of(pagina(0)));
    const { el, filas } = crear();

    expect(filas().length).toBe(0);
    expect(el.textContent).toContain('No hay registros.');
  });

  it('muestra el mensaje de error si falla la consulta', () => {
    listar.mockReturnValue(throwError(() => new HttpErrorResponse({ status: 0 })));
    const { el } = crear();

    expect(el.querySelector('[role="alert"]')?.textContent).toContain(
      'No se pudo conectar con el servidor.',
    );
  });

  it('al cambiar de pestaña consulta ese recurso desde la página 1', () => {
    const { boton, fixture } = crear();

    boton('Cambios de estado').click();
    fixture.detectChanges();

    expect(listar).toHaveBeenLastCalledWith(
      'historial-estados',
      expect.objectContaining({ page: 1 }),
    );
    expect(boton('Cambios de estado').disabled).toBe(true);
  });

  it('al filtrar envía búsqueda, fechas y orden, y vuelve a la página 1', () => {
    const { el, fixture } = crear();

    (el.querySelector('input[type="search"]') as HTMLInputElement).value = '  examen ';
    const fechas = el.querySelectorAll<HTMLInputElement>('input[type="date"]');
    fechas[0].value = '2026-10-01';
    fechas[1].value = '2026-10-09';
    (el.querySelector('select') as HTMLSelectElement).value = 'fecha';
    el.querySelector('form')!.dispatchEvent(new Event('submit'));
    fixture.detectChanges();

    expect(listar).toHaveBeenLastCalledWith('auditoria', {
      page: 1,
      search: 'examen',
      desde: '2026-10-01',
      hasta: '2026-10-09',
      ordering: 'fecha',
    });
  });

  it('pagina: «Anterior» está deshabilitado en la 1 y «Siguiente» pide la 2', () => {
    listar.mockReturnValue(of(pagina(10, 25)));
    const { el, boton, fixture } = crear();

    expect(el.textContent).toContain('Página 1 de 3');
    expect(boton('Anterior').disabled).toBe(true);

    boton('Siguiente').click();
    fixture.detectChanges();

    expect(listar).toHaveBeenLastCalledWith('auditoria', expect.objectContaining({ page: 2 }));
  });
});