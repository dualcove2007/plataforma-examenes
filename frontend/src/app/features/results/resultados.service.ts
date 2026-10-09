import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';
import { Tipo } from '../question-bank/preguntas.service';

export type EstadoRevision = 'pendiente' | 'en_revision' | 'revisado';

export const ETIQUETA_REVISION: Record<EstadoRevision, string> = {
  pendiente: 'Pendiente',
  en_revision: 'En revisión',
  revisado: 'Revisado',
};

export const ESTADOS_REVISION = (Object.keys(ETIQUETA_REVISION) as EstadoRevision[]).map(
  (valor) => ({ valor, etiqueta: ETIQUETA_REVISION[valor] }),
);

export interface Resultado {
  id: number;
  intento: number;
  examen: number;
  examen_titulo: string;
  estudiante: string;
  estudiante_email: string;
  numero_intento: number;
  intento_estado: string;
  puntaje_total: number | null;
  puntaje_maximo: number;
  nota_final: number | null;
  estado_revision: EstadoRevision;
  revisado_por: number | null;
  fecha_revision: string | null;
}

export interface RespuestaResultado {
  id: number;
  pregunta: number;
  enunciado: string;
  tipo: Tipo;
  puntaje_maximo: number | null;
  texto_respuesta: string;
  opciones_seleccionadas: { id: number; texto: string }[];
  puntaje_obtenido: number | null;
  es_correcta: boolean | null;
}

export interface ResultadoDetalle extends Resultado {
  respuestas: RespuestaResultado[];
}

export interface Calificacion {
  respuesta: number;
  puntaje: number;
}

export interface FiltrosResultados {
  page: number;
  search?: string;
  estado_revision?: EstadoRevision;
}

@Injectable({ providedIn: 'root' })
export class ResultadosService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/resultados/`;

  listar(f: FiltrosResultados): Observable<Pagina<Resultado>> {
    let params = new HttpParams().set('page', f.page);
    if (f.search) params = params.set('search', f.search);
    if (f.estado_revision) params = params.set('estado_revision', f.estado_revision);
    return this.http.get<Pagina<Resultado>>(this.url, { params });
  }

  obtener(id: number): Observable<ResultadoDetalle> {
    return this.http.get<ResultadoDetalle>(`${this.url}${id}/`);
  }

  calificar(id: number, calificaciones: Calificacion[]): Observable<Resultado> {
    return this.http.post<Resultado>(`${this.url}${id}/calificar/`, { calificaciones });
  }
}