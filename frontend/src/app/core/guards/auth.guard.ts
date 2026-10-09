import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

import { NombreRol } from '../models/auth.models';
import { AuthService } from '../services/auth.service';

/** Exige sesión iniciada; si no, va a /login recordando a dónde quería ir. */
export const authGuard: CanActivateFn = (_route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.autenticado()
    ? true
    : router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};

/** Para /login: si ya hay sesión, no tiene sentido mostrarlo. */
export const guestGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.autenticado() ? router.createUrlTree(['/dashboard']) : true;
};

/** Uso: { path: 'usuarios', canActivate: [rolGuard(Rol.Administrador)] } */
export const rolGuard =
  (...roles: NombreRol[]): CanActivateFn =>
  () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    return auth.tieneRol(...roles) ? true : router.createUrlTree(['/dashboard']);
  };

/** Uso: { path: 'auditoria', canActivate: [permisoGuard('auditoria.ver')] } */
export const permisoGuard =
  (codigo: string): CanActivateFn =>
  () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    return auth.tienePermiso(codigo) ? true : router.createUrlTree(['/dashboard']);
  };
