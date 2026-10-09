import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export interface Notificacion {
  id: number;
  tipo: 'examen_asignado' | 'examen_publicado' | 'resultado_revisado';
  titulo: string;
  mensaje: string;
  entidad: string;
  entidad_id: string;
  leida: boolean;
  fecha_creacion: string;
  fecha_lectura: string | null;
}

@Injectable({ providedIn: 'root' })
export class NotificacionesService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/notificaciones/`;

  /** Contador compartido con la barra superior. */
  readonly noLeidas = signal(0);

  listar(page: number, soloNoLeidas: boolean): Observable<Pagina<Notificacion>> {
    let params = new HttpParams().set('page', page);
    if (soloNoLeidas) params = params.set('leida', 'false');
    return this.http.get<Pagina<Notificacion>>(this.url, { params });
  }

  refrescarContador(): void {
    this.http.get<{ no_leidas: number }>(`${this.url}no-leidas/`).subscribe({
      next: (r) => this.noLeidas.set(r.no_leidas),
      error: () => {
        /* el contador no es crítico: se reintenta en el siguiente ciclo */
      },
    });
  }

  marcarLeida(id: number): Observable<Notificacion> {
    return this.http
      .post<Notificacion>(`${this.url}${id}/marcar-leida/`, {})
      .pipe(tap(() => this.refrescarContador()));
  }

  marcarTodas(): Observable<{ marcadas: number }> {
    return this.http
      .post<{ marcadas: number }>(`${this.url}marcar-todas/`, {})
      .pipe(tap(() => this.refrescarContador()));
  }
}