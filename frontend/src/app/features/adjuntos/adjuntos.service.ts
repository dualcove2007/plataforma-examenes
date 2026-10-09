import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export type DuenoAdjunto = 'pregunta' | 'examen';

export interface Adjunto {
  id: number;
  pregunta: number | null;
  examen: number | null;
  nombre_original: string;
  tipo_mime: string;
  tamano: number;
  subido_por: number;
  subido_por_nombre: string;
  fecha_creacion: string;
}

@Injectable({ providedIn: 'root' })
export class AdjuntosService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/adjuntos/`;

  listar(dueno: DuenoAdjunto, id: number): Observable<Adjunto[]> {
    const params = new HttpParams().set(dueno, id);
    return this.http.get<Pagina<Adjunto>>(this.url, { params }).pipe(map((p) => p.results));
  }

  subir(dueno: DuenoAdjunto, id: number, archivo: File): Observable<Adjunto> {
    const datos = new FormData();
    datos.append('archivo', archivo);
    datos.append(dueno, String(id));
    return this.http.post<Adjunto>(this.url, datos);
  }

  eliminar(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}${id}/`);
  }

  descargar(id: number): Observable<Blob> {
    return this.http.get(`${this.url}${id}/descargar/`, { responseType: 'blob' });
  }
}