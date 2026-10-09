import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { environment } from '../../../environments/environment';
import { Rol, Usuario } from '../models/auth.models';
import { AuthService } from './auth.service';

const API = environment.apiUrl;

const docente: Usuario = {
  id: 1,
  nombre: 'Docente Demo',
  email: 'docente@demo.com',
  rol: Rol.Docente,
  permisos: ['examenes.ver', 'examenes.crear'],
  activo: true,
  fecha_creacion: '2026-01-01T00:00:00Z',
};

describe('AuthService', () => {
  let auth: AuthService;
  let http: HttpTestingController;
  let router: Router;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideRouter([]), provideHttpClient(), provideHttpClientTesting()],
    });
    auth = TestBed.inject(AuthService);
    http = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
  });

  afterEach(() => {
    http.verify();
    localStorage.clear();
  });

  describe('login', () => {
    it('guarda el access en memoria, el refresh en localStorage y el usuario', () => {
      let resultado: Usuario | undefined;
      auth.login({ email: 'docente@demo.com', password: 'x' }).subscribe((u) => (resultado = u));

      const req = http.expectOne(`${API}/auth/login/`);
      expect(req.request.method).toBe('POST');
      req.flush({ access: 'A1', refresh: 'R1', usuario: docente });

      expect(resultado).toEqual(docente);
      expect(auth.accessToken()).toBe('A1');
      expect(auth.refreshToken()).toBe('R1');
      expect(auth.usuario()).toEqual(docente);
      expect(auth.autenticado()).toBe(true);
    });

    it('no deja sesión si las credenciales son incorrectas', () => {
      let fallo = false;
      auth.login({ email: 'a@b.com', password: 'mal' }).subscribe({ error: () => (fallo = true) });

      http
        .expectOne(`${API}/auth/login/`)
        .flush({ error: { mensaje: 'Credenciales inválidas.' } }, { status: 401, statusText: 'x' });

      expect(fallo).toBe(true);
      expect(auth.autenticado()).toBe(false);
      expect(auth.refreshToken()).toBeNull();
    });
  });

  describe('logout', () => {
    function iniciarSesion() {
      auth.login({ email: 'docente@demo.com', password: 'x' }).subscribe();
      http.expectOne(`${API}/auth/login/`).flush({ access: 'A1', refresh: 'R1', usuario: docente });
    }

    it('avisa al backend y limpia la sesión local', () => {
      iniciarSesion();
      auth.logout();

      const req = http.expectOne(`${API}/auth/logout/`);
      expect(req.request.body).toEqual({ refresh: 'R1' });
      req.flush({});

      expect(auth.autenticado()).toBe(false);
      expect(auth.refreshToken()).toBeNull();
      expect(router.navigate).toHaveBeenCalledWith(['/login']);
    });

    it('limpia la sesión local aunque el backend falle', () => {
      iniciarSesion();
      auth.logout();

      http.expectOne(`${API}/auth/logout/`).flush('boom', { status: 500, statusText: 'x' });

      expect(auth.autenticado()).toBe(false);
      expect(auth.refreshToken()).toBeNull();
      expect(router.navigate).toHaveBeenCalledWith(['/login']);
    });

    it('sin sesión no llama al backend, solo va a /login', () => {
      auth.logout();
      http.expectNone(`${API}/auth/logout/`);
      expect(router.navigate).toHaveBeenCalledWith(['/login']);
    });
  });

  describe('restaurarSesion', () => {
    it('sin refresh token no hace ninguna petición', () => {
      let terminado = false;
      auth.restaurarSesion().subscribe(() => (terminado = true));
      http.expectNone(`${API}/auth/refresh/`);
      expect(terminado).toBe(true);
      expect(auth.autenticado()).toBe(false);
    });

    it('con refresh token renueva y carga el usuario', () => {
      localStorage.setItem('refresh_token', 'R1');
      auth.restaurarSesion().subscribe();

      http.expectOne(`${API}/auth/refresh/`).flush({ access: 'A2', refresh: 'R2' });
      http.expectOne(`${API}/auth/me/`).flush(docente);

      expect(auth.accessToken()).toBe('A2');
      expect(auth.refreshToken()).toBe('R2'); // el backend rota el refresh
      expect(auth.usuario()).toEqual(docente);
      expect(auth.autenticado()).toBe(true);
    });

    it('si el refresh ya no sirve, limpia todo y no rompe el arranque', () => {
      localStorage.setItem('refresh_token', 'vencido');
      let terminado = false;
      auth.restaurarSesion().subscribe(() => (terminado = true));

      http
        .expectOne(`${API}/auth/refresh/`)
        .flush({ detail: 'inválido' }, { status: 401, statusText: 'x' });

      expect(terminado).toBe(true);
      expect(auth.autenticado()).toBe(false);
      expect(auth.refreshToken()).toBeNull();
    });
  });

  describe('refrescar', () => {
    it('falla si no hay refresh token', () => {
      let fallo = false;
      auth.refrescar().subscribe({ error: () => (fallo = true) });
      http.expectNone(`${API}/auth/refresh/`);
      expect(fallo).toBe(true);
    });

    it('varias llamadas simultáneas comparten una sola petición', () => {
      localStorage.setItem('refresh_token', 'R1');
      const resultados: string[] = [];
      auth.refrescar().subscribe((t) => resultados.push(t));
      auth.refrescar().subscribe((t) => resultados.push(t));
      auth.refrescar().subscribe((t) => resultados.push(t));

      const req = http.expectOne(`${API}/auth/refresh/`); // expectOne falla si hay más de una
      req.flush({ access: 'A2', refresh: 'R2' });

      expect(resultados).toEqual(['A2', 'A2', 'A2']);
    });

    it('permite una renovación nueva una vez terminada la anterior', () => {
      localStorage.setItem('refresh_token', 'R1');
      auth.refrescar().subscribe();
      http.expectOne(`${API}/auth/refresh/`).flush({ access: 'A2', refresh: 'R2' });

      auth.refrescar().subscribe();
      const req = http.expectOne(`${API}/auth/refresh/`);
      expect(req.request.body).toEqual({ refresh: 'R2' });
      req.flush({ access: 'A3', refresh: 'R3' });
    });
  });

  describe('permisos', () => {
    beforeEach(() => auth.usuario.set(docente));

    it('tieneRol acepta cualquiera de los roles indicados', () => {
      expect(auth.tieneRol(Rol.Docente)).toBe(true);
      expect(auth.tieneRol(Rol.Administrador, Rol.Docente)).toBe(true);
      expect(auth.tieneRol(Rol.Estudiante)).toBe(false);
    });

    it('tienePermiso consulta la lista de permisos del usuario', () => {
      expect(auth.tienePermiso('examenes.crear')).toBe(true);
      expect(auth.tienePermiso('usuarios.eliminar')).toBe(false);
    });

    it('sin usuario no hay roles ni permisos', () => {
      auth.usuario.set(null);
      expect(auth.tieneRol(Rol.Docente)).toBe(false);
      expect(auth.tienePermiso('examenes.ver')).toBe(false);
    });
  });
});