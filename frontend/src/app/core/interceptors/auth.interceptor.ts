import { HttpErrorResponse, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, switchMap, throwError } from 'rxjs';

import { environment } from '../../../environments/environment';
import { AuthService } from '../services/auth.service';

const RUTAS_PUBLICAS = /\/auth\/(login|refresh)\/$/;

/**
 * 1. Agrega "Authorization: Bearer <access>" a las peticiones a la API.
 * 2. Si la API responde 401, renueva el token UNA vez y reintenta.
 * 3. Si la renovación falla, cierra la sesión y va a /login.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);

  if (!req.url.startsWith(environment.apiUrl) || RUTAS_PUBLICAS.test(req.url)) {
    return next(req);
  }

  const conToken = (r: HttpRequest<unknown>, token: string) =>
    r.clone({ setHeaders: { Authorization: `Bearer ${token}` } });

  const token = auth.accessToken();

  return next(token ? conToken(req, token) : req).pipe(
    catchError((err: unknown) => {
      const esNoAutorizado = err instanceof HttpErrorResponse && err.status === 401;
      if (!esNoAutorizado || !auth.refreshToken()) {
        return throwError(() => err);
      }
      return auth.refrescar().pipe(
        // Solo falla aquí si la renovación falló (no si falla el reintento)
        catchError((errRefresh) => {
          auth.cerrarSesionLocal();
          return throwError(() => errRefresh);
        }),
        switchMap((nuevo) => next(conToken(req, nuevo))),
      );
    }),
  );
};
