import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';
import { RespuestaResultado, Resultado } from './resultados.service';

export interface RespuestaEstudiante extends RespuestaResultado {
  opciones_correctas: { id: number; texto: string }[];
}

export interface MiResultadoDetalle extends Resultado {
  detalle_disponible: boolean;
  respuestas: RespuestaEstudiante[] | null;
}

@Injectable({ providedIn: 'root' })
export class MisResultadosService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/mis-resultados/`;

  listar(page: number): Observable<Pagina<Resultado>> {
    const params = new HttpParams().set('page', page);
    return this.http.get<Pagina<Resultado>>(this.url, { params });
  }

  obtener(id: number): Observable<MiResultadoDetalle> {
    return this.http.get<MiResultadoDetalle>(`${this.url}${id}/`);
  }

  constancia(id: number): Observable<Blob> {
    return this.http.get(`${environment.apiUrl}/reportes/constancia/${id}/`, {
      responseType: 'blob',
    });
  }
}