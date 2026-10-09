import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export type EstadoAsignacion = 'pendiente' | 'en_progreso' | 'completado' | 'vencido';

export const ETIQUETA_ASIGNACION: Record<EstadoAsignacion, string> = {
  pendiente: 'Pendiente',
  en_progreso: 'En progreso',
  completado: 'Completado',
  vencido: 'Vencido',
};

export interface MiExamen {
  id: number; // id de la asignación
  examen: number;
  titulo: string;
  materia: string;
  fecha_inicio: string;
  fecha_fin: string;
  duracion_minutos: number;
  intentos_permitidos: number;
  examen_estado: string;
  estado: EstadoAsignacion;
  total_preguntas: number;
}

@Injectable({ providedIn: 'root' })
export class MisExamenesService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/mis-examenes/`;

  listar(page: number): Observable<Pagina<MiExamen>> {
    const params = new HttpParams().set('page', page);
    return this.http.get<Pagina<MiExamen>>(this.url, { params });
  }
}