import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { Tipo } from '../question-bank/preguntas.service';
import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export type EstadoExamen = 'borrador' | 'publicado' | 'cerrado' | 'archivado';
export type AccionEstado = 'publicar' | 'cerrar' | 'archivar';

export const ETIQUETA_ESTADO_EXAMEN: Record<EstadoExamen, string> = {
  borrador: 'Borrador',
  publicado: 'Publicado',
  cerrado: 'Cerrado',
  archivado: 'Archivado',
};

export const ESTADOS_EXAMEN = (Object.keys(ETIQUETA_ESTADO_EXAMEN) as EstadoExamen[]).map(
  (valor) => ({ valor, etiqueta: ETIQUETA_ESTADO_EXAMEN[valor] }),
);

export interface Examen {
  id: number;
  materia: number;
  materia_nombre: string;
  titulo: string;
  descripcion: string;
  fecha_inicio: string;
  fecha_fin: string;
  duracion_minutos: number;
  intentos_permitidos: number;
  estado: EstadoExamen;
  fecha_creacion: string;
  total_preguntas: number;
  puntaje_total: number | null;
}

export interface ExamenEscritura {
  materia: number;
  titulo: string;
  descripcion: string;
  fecha_inicio: string;
  fecha_fin: string;
  duracion_minutos: number;
  intentos_permitidos: number;
}

export interface FiltrosExamenes {
  page: number;
  search?: string;
  estado?: EstadoExamen;
}

export interface ExamenPregunta {
  id: number;
  pregunta: number;
  orden: number;
  puntaje: number;
  enunciado: string;
  tipo: Tipo;
  dificultad: string;
}

export interface ExamenDetalle extends Examen {
  preguntas: ExamenPregunta[];
}

export interface Asignacion {
  id: number;
  estudiante: number;
  estudiante_nombre: string;
  estudiante_email: string;
  fecha_asignacion: string;
  estado: string;
}

export interface Estudiante {
  id: number;
  nombre: string;
  email: string;
}

@Injectable({ providedIn: 'root' })
export class ExamenesService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/examenes/`;

  listar(f: FiltrosExamenes): Observable<Pagina<Examen>> {
    let params = new HttpParams().set('page', f.page);
    if (f.search) params = params.set('search', f.search);
    if (f.estado) params = params.set('estado', f.estado);
    return this.http.get<Pagina<Examen>>(this.url, { params });
  }

  obtener(id: number): Observable<Examen> {
    return this.http.get<Examen>(`${this.url}${id}/`);
  }

  crear(datos: ExamenEscritura): Observable<Examen> {
    return this.http.post<Examen>(this.url, datos);
  }

  actualizar(id: number, datos: ExamenEscritura): Observable<Examen> {
    return this.http.patch<Examen>(`${this.url}${id}/`, datos);
  }

  /** Solo se eliminan exámenes en borrador. */
  eliminar(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}${id}/`);
  }

  cambiarEstado(id: number, accion: AccionEstado): Observable<{ id: number; estado: EstadoExamen }> {
    return this.http.post<{ id: number; estado: EstadoExamen }>(`${this.url}${id}/${accion}/`, {});
  }

  obtenerDetalle(id: number): Observable<ExamenDetalle> {
    return this.http.get<ExamenDetalle>(`${this.url}${id}/`);
  }

  agregarPregunta(id: number, pregunta: number): Observable<ExamenPregunta> {
    return this.http.post<ExamenPregunta>(`${this.url}${id}/agregar-pregunta/`, { pregunta });
  }

  quitarPregunta(id: number, pregunta: number): Observable<void> {
    return this.http.post<void>(`${this.url}${id}/quitar-pregunta/`, { pregunta });
  }

  asignaciones(id: number): Observable<Asignacion[]> {
    return this.http.get<Asignacion[]>(`${this.url}${id}/asignaciones/`);
  }

  asignar(id: number, estudiantes: number[]): Observable<unknown> {
    return this.http.post<unknown>(`${this.url}${id}/asignar/`, { estudiantes });
  }

  estudiantes(page: number, search?: string): Observable<Pagina<Estudiante>> {
    let params = new HttpParams().set('page', page);
    if (search) params = params.set('search', search);
    return this.http.get<Pagina<Estudiante>>(`${environment.apiUrl}/estudiantes/`, { params });
  }
}