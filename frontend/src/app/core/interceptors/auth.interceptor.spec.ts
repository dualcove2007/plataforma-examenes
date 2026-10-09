import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { environment } from '../../../environments/environment';
import { AuthService } from '../services/auth.service';
import { authInterceptor } from './auth.interceptor';

const API = environment.apiUrl;

describe('authInterceptor', () => {
  let client: HttpClient;
  let http: HttpTestingController;
  let auth: AuthService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    client = TestBed.inject(HttpClient);
    http = TestBed.inject(HttpTestingController);
    auth = TestBed.inject(AuthService);
    vi.spyOn(TestBed.inject(Router), 'navigate').mockResolvedValue(true);
  });

  afterEach(() => {
    http.verify();
    localStorage.clear();
  });

  it('agrega el Bearer token a las peticiones a la API', () => {
    auth.accessToken.set('A1');
    client.get(`${API}/examenes/`).subscribe();

    const req = http.expectOne(`${API}/examenes/`);
    expect(req.request.headers.get('Authorization')).toBe('Bearer A1');
    req.flush([]);
  });

  it('no agrega token si no hay sesión', () => {
    client.get(`${API}/examenes/`).subscribe();

    const req = http.expectOne(`${API}/examenes/`);
    expect(req.request.headers.has('Authorization')).toBe(false);
    req.flush([]);
  });

  it('no manda el token a URLs que no son de la API', () => {
    auth.accessToken.set('A1');
    client.get('https://otro-sitio.com/datos').subscribe();

    const req = http.expectOne('https://otro-sitio.com/datos');
    expect(req.request.headers.has('Authorization')).toBe(false);
    req.flush({});
  });

  it('no manda el token en login ni en refresh', () => {
    auth.accessToken.set('A1');
    client.post(`${API}/auth/login/`, {}).subscribe();
    client.post(`${API}/auth/refresh/`, {}).subscribe();

    const login = http.expectOne(`${API}/auth/login/`);
    const refresh = http.expectOne(`${API}/auth/refresh/`);
    expect(login.request.headers.has('Authorization')).toBe(false);
    expect(refresh.request.headers.has('Authorization')).toBe(false);
    login.flush({});
    refresh.flush({});
  });

  it('ante un 401 renueva el token y reintenta la petición', () => {
    auth.accessToken.set('VENCIDO');
    localStorage.setItem('refresh_token', 'R1');
    let respuesta: unknown;
    client.get(`${API}/examenes/`).subscribe((r) => (respuesta = r));

    http
      .expectOne(`${API}/examenes/`)
      .flush({ detail: 'expirado' }, { status: 401, statusText: 'Unauthorized' });

    http.expectOne(`${API}/auth/refresh/`).flush({ access: 'NUEVO', refresh: 'R2' });

    const reintento = http.expectOne(`${API}/examenes/`);
    expect(reintento.request.headers.get('Authorization')).toBe('Bearer NUEVO');
    reintento.flush({ ok: true });

    expect(respuesta).toEqual({ ok: true });
  });

  it('varias peticiones con 401 provocan una sola renovación', () => {
    auth.accessToken.set('VENCIDO');
    localStorage.setItem('refresh_token', 'R1');
    client.get(`${API}/a/`).subscribe();
    client.get(`${API}/b/`).subscribe();

    http.expectOne(`${API}/a/`).flush(null, { status: 401, statusText: 'x' });
    http.expectOne(`${API}/b/`).flush(null, { status: 401, statusText: 'x' });

    http.expectOne(`${API}/auth/refresh/`).flush({ access: 'NUEVO', refresh: 'R2' });

    http.expectOne(`${API}/a/`).flush({});
    http.expectOne(`${API}/b/`).flush({});
  });

  it('si la renovación falla, cierra la sesión y propaga el error', () => {
    auth.accessToken.set('VENCIDO');
    localStorage.setItem('refresh_token', 'R1');
    const cerrar = vi.spyOn(auth, 'cerrarSesionLocal');
    let fallo = false;
    client.get(`${API}/examenes/`).subscribe({ error: () => (fallo = true) });

    http.expectOne(`${API}/examenes/`).flush(null, { status: 401, statusText: 'x' });
    http.expectOne(`${API}/auth/refresh/`).flush(null, { status: 401, statusText: 'x' });

    expect(cerrar).toHaveBeenCalledOnce();
    expect(fallo).toBe(true);
  });

  it('un 401 sin refresh token se propaga sin intentar renovar', () => {
    auth.accessToken.set('A1');
    let status = 0;
    client.get(`${API}/examenes/`).subscribe({ error: (e) => (status = e.status) });

    http.expectOne(`${API}/examenes/`).flush(null, { status: 401, statusText: 'x' });

    http.expectNone(`${API}/auth/refresh/`);
    expect(status).toBe(401);
  });

  it('un 403 no dispara renovación', () => {
    auth.accessToken.set('A1');
    localStorage.setItem('refresh_token', 'R1');
    let status = 0;
    client.get(`${API}/usuarios/`).subscribe({ error: (e) => (status = e.status) });

    http.expectOne(`${API}/usuarios/`).flush(null, { status: 403, statusText: 'Forbidden' });

    http.expectNone(`${API}/auth/refresh/`);
    expect(status).toBe(403);
  });

  it('si el reintento también falla, no cierra la sesión', () => {
    auth.accessToken.set('VENCIDO');
    localStorage.setItem('refresh_token', 'R1');
    const cerrar = vi.spyOn(auth, 'cerrarSesionLocal');
    let status = 0;
    client.get(`${API}/examenes/`).subscribe({ error: (e) => (status = e.status) });

    http.expectOne(`${API}/examenes/`).flush(null, { status: 401, statusText: 'x' });
    http.expectOne(`${API}/auth/refresh/`).flush({ access: 'NUEVO', refresh: 'R2' });
    http.expectOne(`${API}/examenes/`).flush(null, { status: 500, statusText: 'x' });

    expect(status).toBe(500);
    expect(cerrar).not.toHaveBeenCalled();
  });
});