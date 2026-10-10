import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export type RecursoAuditoria = 'auditoria' | 'historial' | 'historial-estados';

export interface RegistroAuditoria {
  id: number;
  usuario_nombre: string | null;
  accion: string;
  entidad: string;
  entidad_id: string;
  ip_address: string | null;
  fecha: string;
  detalle: Record<string, unknown>;
}

export interface RegistroCambio {
  id: number;
  usuario_nombre: string | null;
  entidad: string;
  entidad_id: string;
  campo: string;
  valor_anterior: string | null;
  valor_nuevo: string | null;
  fecha: string;
}

export interface RegistroEstado {
  id: number;
  usuario_nombre: string | null;
  entidad: string;
  entidad_id: string;
  estado_anterior: string;
  estado_nuevo: string;
  fecha: string;
}

export interface FiltrosAuditoria {
  page: number;
  search?: string;
  desde?: string;
  hasta?: string;
  ordering: string;
}

@Injectable({ providedIn: 'root' })
export class AuditoriaService {
  private readonly http = inject(HttpClient);

  listar<T>(recurso: RecursoAuditoria, f: FiltrosAuditoria): Observable<Pagina<T>> {
    let params = new HttpParams().set('page', f.page).set('ordering', f.ordering);
    if (f.search) params = params.set('search', f.search);
    if (f.desde) params = params.set('desde', f.desde);
    if (f.hasta) params = params.set('hasta', f.hasta);
    return this.http.get<Pagina<T>>(`${environment.apiUrl}/${recurso}/`, { params });
  }
}