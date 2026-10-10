import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Tipo } from '../question-bank/preguntas.service';

export interface OpcionIntento {
  id: number;
  texto: string;
}

export interface PreguntaIntento {
  pregunta: number;
  orden: number;
  puntaje: number;
  enunciado: string;
  tipo: Tipo;
  opciones: OpcionIntento[];
  respuesta: { texto_respuesta: string; opciones: number[] } | null;
}

export interface Intento {
  id: number;
  asignacion: number;
  examen: number;
  titulo: string;
  numero_intento: number;
  estado: 'en_progreso' | 'finalizado' | 'expirado' | 'anulado';
  fecha_inicio: string;
  fecha_limite: string;
  fecha_fin: string | null;
  segundos_restantes: number;
  preguntas?: PreguntaIntento[];
}

export interface ResultadoIntento {
  id: number;
  examen_titulo: string;
  puntaje_total: number | null;
  puntaje_maximo: number;
  nota_final: number | null;
  estado_revision: 'pendiente' | 'en_revision' | 'revisado';
}

export type TipoEvento = 'salida_pestana' | 'pegado';
export interface CuerpoRespuesta {
  pregunta: number;
  opciones: number[];
  texto_respuesta: string;
}

@Injectable({ providedIn: 'root' })
export class IntentosService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/intentos/`;

  /** Inicia un intento nuevo o reanuda el que está en progreso. */
  iniciar(asignacion: number): Observable<Intento> {
    return this.http.post<Intento>(this.url, { asignacion });
  }

  obtener(id: number): Observable<Intento> {
    return this.http.get<Intento>(`${this.url}${id}/`);
  }

  responder(
    id: number,
    cuerpo: CuerpoRespuesta,
  ): Observable<{ guardada: boolean; segundos_restantes: number }> {
    return this.http.post<{ guardada: boolean; segundos_restantes: number }>(
      `${this.url}${id}/responder/`,
      cuerpo,
    );
  }

  /** Anti-trampa: avisa que el estudiante salió de la pestaña o pegó texto. */
  registrarEvento(
    id: number,
    tipo: TipoEvento,
    duracionSegundos?: number,
  ): Observable<{ registrado: boolean }> {
    const cuerpo: { tipo: TipoEvento; duracion_segundos?: number } = { tipo };
    if (duracionSegundos !== undefined) cuerpo.duracion_segundos = duracionSegundos;
    return this.http.post<{ registrado: boolean }>(`${this.url}${id}/eventos/`, cuerpo);
  }
  
  enviar(id: number): Observable<ResultadoIntento> {
    return this.http.post<ResultadoIntento>(`${this.url}${id}/enviar/`, {});
  }
}