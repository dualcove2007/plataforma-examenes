import { TestBed } from '@angular/core/testing';
import {
  ActivatedRouteSnapshot,
  CanActivateFn,
  RouterStateSnapshot,
  UrlTree,
  provideRouter,
} from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { Rol, Usuario } from '../models/auth.models';
import { AuthService } from '../services/auth.service';
import { authGuard, guestGuard, permisoGuard, rolGuard } from './auth.guard';

function usuario(rol: Usuario['rol'], permisos: string[] = []): Usuario {
  return {
    id: 1,
    nombre: 'Test',
    email: 't@t.com',
    rol,
    permisos,
    activo: true,
    fecha_creacion: '2026-01-01T00:00:00Z',
  };
}

describe('guards', () => {
  let auth: AuthService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({ providers: [provideRouter([])] });
    auth = TestBed.inject(AuthService);
  });

  function ejecutar(guard: CanActivateFn, url = '/dashboard') {
    return TestBed.runInInjectionContext(() =>
      guard({} as ActivatedRouteSnapshot, { url } as RouterStateSnapshot),
    ) as boolean | UrlTree;
  }

  function iniciarSesion(u: Usuario) {
    auth.accessToken.set('A1');
    auth.usuario.set(u);
  }

  describe('authGuard', () => {
    it('deja pasar si hay sesión', () => {
      iniciarSesion(usuario(Rol.Docente));
      expect(ejecutar(authGuard)).toBe(true);
    });

    it('sin sesión redirige a /login guardando la URL pedida', () => {
      const res = ejecutar(authGuard, '/examenes') as UrlTree;
      expect(res.toString()).toBe('/login?returnUrl=%2Fexamenes');
    });
  });

  describe('guestGuard', () => {
    it('deja ver /login si no hay sesión', () => {
      expect(ejecutar(guestGuard)).toBe(true);
    });

    it('con sesión redirige a /dashboard', () => {
      iniciarSesion(usuario(Rol.Estudiante));
      expect((ejecutar(guestGuard) as UrlTree).toString()).toBe('/dashboard');
    });
  });

  describe('rolGuard', () => {
    it('deja pasar si el rol coincide', () => {
      iniciarSesion(usuario(Rol.Administrador));
      expect(ejecutar(rolGuard(Rol.Administrador))).toBe(true);
    });

    it('acepta varios roles', () => {
      iniciarSesion(usuario(Rol.Docente));
      expect(ejecutar(rolGuard(Rol.Administrador, Rol.Docente))).toBe(true);
    });

    it('redirige a /dashboard si el rol no corresponde', () => {
      iniciarSesion(usuario(Rol.Estudiante));
      expect((ejecutar(rolGuard(Rol.Administrador)) as UrlTree).toString()).toBe('/dashboard');
    });

    it('sin sesión tampoco deja pasar', () => {
      expect(ejecutar(rolGuard(Rol.Docente)) instanceof UrlTree).toBe(true);
    });
  });

  describe('permisoGuard', () => {
    it('deja pasar si el usuario tiene el permiso', () => {
      iniciarSesion(usuario(Rol.Docente, ['examenes.crear']));
      expect(ejecutar(permisoGuard('examenes.crear'))).toBe(true);
    });

    it('redirige a /dashboard si no lo tiene', () => {
      iniciarSesion(usuario(Rol.Docente, ['examenes.ver']));
      expect((ejecutar(permisoGuard('examenes.crear')) as UrlTree).toString()).toBe('/dashboard');
    });
  });
});