import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { environment } from '../../../environments/environment';
import { AuditoriaService } from './auditoria.service';

const API = environment.apiUrl;

describe('AuditoriaService', () => {
  let servicio: AuditoriaService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    servicio = TestBed.inject(AuditoriaService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('consulta /auditoria/ con página y orden', () => {
    servicio.listar('auditoria', { page: 2, ordering: '-fecha' }).subscribe();

    const req = http.expectOne((r) => r.url === `${API}/auditoria/`);
    expect(req.request.method).toBe('GET');
    expect(req.request.params.get('page')).toBe('2');
    expect(req.request.params.get('ordering')).toBe('-fecha');
    expect(req.request.params.has('search')).toBe(false);
    req.flush({ count: 0, next: null, previous: null, results: [] });
  });

  it('envía búsqueda y rango de fechas solo cuando tienen valor', () => {
    servicio
      .listar('historial', {
        page: 1,
        ordering: 'fecha',
        search: 'examen',
        desde: '2026-10-01',
        hasta: '2026-10-09',
      })
      .subscribe();

    const req = http.expectOne((r) => r.url === `${API}/historial/`);
    expect(req.request.params.get('search')).toBe('examen');
    expect(req.request.params.get('desde')).toBe('2026-10-01');
    expect(req.request.params.get('hasta')).toBe('2026-10-09');
    req.flush({ count: 0, next: null, previous: null, results: [] });
  });

  it('omite filtros vacíos', () => {
    servicio
      .listar('historial-estados', { page: 1, ordering: '-fecha', search: '', desde: '', hasta: '' })
      .subscribe();

    const req = http.expectOne((r) => r.url === `${API}/historial-estados/`);
    expect(req.request.params.has('search')).toBe(false);
    expect(req.request.params.has('desde')).toBe(false);
    expect(req.request.params.has('hasta')).toBe(false);
    req.flush({ count: 0, next: null, previous: null, results: [] });
  });

  it('devuelve la página que responde el backend', () => {
    let total = -1;
    servicio.listar('auditoria', { page: 1, ordering: '-fecha' }).subscribe((p) => (total = p.count));

    http
      .expectOne((r) => r.url === `${API}/auditoria/`)
      .flush({ count: 3, next: null, previous: null, results: [] });

    expect(total).toBe(3);
  });
});