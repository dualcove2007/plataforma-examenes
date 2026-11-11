export const Rol = {
  Administrador: 'Administrador',
  Docente: 'Docente',
  Estudiante: 'Estudiante',
} as const;

export type NombreRol = (typeof Rol)[keyof typeof Rol];

export interface Usuario {
  id: number;
  nombre: string;
  email: string;
  rol: NombreRol; // rol de esta sesión
  roles?: NombreRol[]; // todos los roles de la cuenta
  permisos: string[];
  activo: boolean;
  fecha_creacion: string;
}

export interface Tokens {
  access: string;
  refresh: string;
}

export interface LoginRequest {
  email: string;
  password: string;
  /** Solo si la cuenta tiene varios roles: el elegido para esta sesión. */
  rol?: string;
}

export interface LoginResponse extends Tokens {
  usuario: Usuario;
}

/** Respuesta del servidor cuando la cuenta tiene varios roles y falta elegir uno. */
export interface LoginRolPendiente {
  requiere_rol: true;
  roles: string[];
}

/** Resultado del login en la app: la cuenta debe elegir con qué rol entrar. */
export interface RolesPendientes {
  requiereRol: true;
  roles: string[];
}

export function pideRol(r: Usuario | RolesPendientes): r is RolesPendientes {
  return 'requiereRol' in r;
}
