import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ResultadoBorrado } from '../../core/models/borrado';
import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export const TipoPregunta = {
  OpcionUnica: 'opcion_unica',
  OpcionMultiple: 'opcion_multiple',
  VerdaderoFalso: 'verdadero_falso',
  Abierta: 'abierta',
} as const;

export type Tipo = (typeof TipoPregunta)[keyof typeof TipoPregunta];
export type Dificultad = 'facil' | 'media' | 'dificil';

export const ETIQUETA_TIPO: Record<Tipo, string> = {
  opcion_unica: 'Opción única',
  opcion_multiple: 'Opción múltiple',
  verdadero_falso: 'Verdadero o falso',
  abierta: 'Abierta',
};

export const ETIQUETA_DIFICULTAD: Record<Dificultad, string> = {
  facil: 'Fácil',
  media: 'Media',
  dificil: 'Difícil',
};

export const TIPOS = (Object.keys(ETIQUETA_TIPO) as Tipo[]).map((valor) => ({
  valor,
  etiqueta: ETIQUETA_TIPO[valor],
}));

export const DIFICULTADES = (Object.keys(ETIQUETA_DIFICULTAD) as Dificultad[]).map((valor) => ({
  valor,
  etiqueta: ETIQUETA_DIFICULTAD[valor],
}));

export interface Opcion {
  id?: number;
  texto: string;
  es_correcta: boolean;
}

export interface Pregunta {
  id: number;
  banco: number;
  enunciado: string;
  tipo: Tipo;
  dificultad: Dificultad;
  puntaje: number;
  activo: boolean;
  opciones: Opcion[];
}

export interface OpcionEscritura {
  texto: string;
  es_correcta: boolean;
}

export interface PreguntaEscritura {
  banco: number;
  enunciado: string;
  tipo: Tipo;
  dificultad: Dificultad;
  puntaje: number;
  activo: boolean;
  opciones: OpcionEscritura[];
}

export interface FiltrosPreguntas {
  page: number;
  banco: number;
  search?: string;
  tipo?: Tipo;
  dificultad?: Dificultad;
  activo?: boolean;
}

@Injectable({ providedIn: 'root' })
export class PreguntasService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/preguntas/`;

  listar(f: FiltrosPreguntas): Observable<Pagina<Pregunta>> {
    let params = new HttpParams().set('page', f.page).set('banco', f.banco);
    if (f.search) params = params.set('search', f.search);
    if (f.tipo) params = params.set('tipo', f.tipo);
    if (f.dificultad) params = params.set('dificultad', f.dificultad);
    if (f.activo !== undefined) params = params.set('activo', f.activo);
    return this.http.get<Pagina<Pregunta>>(this.url, { params });
  }

  obtener(id: number): Observable<Pregunta> {
    return this.http.get<Pregunta>(`${this.url}${id}/`);
  }

  crear(datos: PreguntaEscritura): Observable<Pregunta> {
    return this.http.post<Pregunta>(this.url, datos);
  }

  actualizar(id: number, datos: PreguntaEscritura): Observable<Pregunta> {
    return this.http.patch<Pregunta>(`${this.url}${id}/`, datos);
  }

  /** Borra la pregunta si no se ha usado; si ya se usó, el backend solo la desactiva. */
  eliminar(id: number): Observable<ResultadoBorrado> {
    return this.http.delete<ResultadoBorrado>(`${this.url}${id}/`);
  }

  plantilla(): Observable<Blob> {
    return this.http.get(`${this.url}plantilla/`, { responseType: 'blob' });
  }

  exportar(f: Omit<FiltrosPreguntas, 'page'>): Observable<Blob> {
    let params = new HttpParams().set('banco', f.banco);
    if (f.search) params = params.set('search', f.search);
    if (f.tipo) params = params.set('tipo', f.tipo);
    if (f.dificultad) params = params.set('dificultad', f.dificultad);
    if (f.activo !== undefined) params = params.set('activo', f.activo);
    return this.http.get(`${this.url}exportar/`, { params, responseType: 'blob' });
  }
}