import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import {
  Observable,
  catchError,
  finalize,
  map,
  of,
  shareReplay,
  switchMap,
  tap,
  throwError,
} from 'rxjs';

import { environment } from '../../../environments/environment';
import { LoginRequest, LoginResponse, NombreRol, Tokens, Usuario } from '../models/auth.models';

const REFRESH_KEY = 'refresh_token';

/**
 * - access token: solo en memoria (se pierde al recargar y se renueva).
 * - refresh token: en localStorage para poder restaurar la sesión.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly api = environment.apiUrl;

  readonly accessToken = signal<string | null>(null);
  readonly usuario = signal<Usuario | null>(null);
  readonly autenticado = computed(() => this.usuario() !== null && this.accessToken() !== null);

  /** Renovación en curso: varias peticiones 401 comparten una sola. */
  private refrescando$?: Observable<string>;

  // ------------------------------ sesión ------------------------------
  login(credenciales: LoginRequest): Observable<Usuario> {
    return this.http.post<LoginResponse>(`${this.api}/auth/login/`, credenciales).pipe(
      tap((res) => {
        this.guardarTokens(res);
        this.usuario.set(res.usuario);
      }),
      map((res) => res.usuario),
    );
  }

  logout(): void {
    const refresh = this.refreshToken();
    if (refresh && this.accessToken()) {
      this.http
        .post(`${this.api}/auth/logout/`, { refresh })
        .pipe(
          catchError(() => of(null)),
          finalize(() => this.cerrarSesionLocal()),
        )
        .subscribe();
    } else {
      this.cerrarSesionLocal();
    }
  }

  /** Limpia la sesión y manda al login (también la usa el interceptor). */
  cerrarSesionLocal(): void {
    this.limpiar();
    void this.router.navigate(['/login']);
  }

  /** Se ejecuta al arrancar la app: recupera la sesión con el refresh token. */
  restaurarSesion(): Observable<unknown> {
    if (!this.refreshToken()) {
      return of(null);
    }
    return this.refrescar().pipe(
      switchMap(() => this.http.get<Usuario>(`${this.api}/auth/me/`)),
      tap((usuario) => this.usuario.set(usuario)),
      catchError(() => {
        this.limpiar();
        return of(null);
      }),
    );
  }

  // ------------------------------ tokens ------------------------------
  refreshToken(): string | null {
    try {
      return localStorage.getItem(REFRESH_KEY);
    } catch {
      return null;
    }
  }

  /** Pide un access nuevo. El backend rota el refresh, así que se guarda también. */
  refrescar(): Observable<string> {
    const refresh = this.refreshToken();
    if (!refresh) {
      return throwError(() => new Error('No hay refresh token.'));
    }
    this.refrescando$ ??= this.http.post<Tokens>(`${this.api}/auth/refresh/`, { refresh }).pipe(
      tap((tokens) => this.guardarTokens(tokens)),
      map((tokens) => tokens.access),
      finalize(() => (this.refrescando$ = undefined)),
      shareReplay(1),
    );
    return this.refrescando$;
  }

  // ------------------------------ permisos ------------------------------
  tieneRol(...roles: NombreRol[]): boolean {
    const rol = this.usuario()?.rol;
    return !!rol && roles.includes(rol);
  }

  tienePermiso(codigo: string): boolean {
    return this.usuario()?.permisos.includes(codigo) ?? false;
  }

  // ------------------------------ internos ------------------------------
  private guardarTokens(tokens: Tokens): void {
    this.accessToken.set(tokens.access);
    try {
      localStorage.setItem(REFRESH_KEY, tokens.refresh);
    } catch {
      /* almacenamiento no disponible: la sesión dura hasta recargar */
    }
  }

  private limpiar(): void {
    this.accessToken.set(null);
    this.usuario.set(null);
    this.refrescando$ = undefined;
    try {
      localStorage.removeItem(REFRESH_KEY);
    } catch {
      /* nada que limpiar */
    }
  }
}
