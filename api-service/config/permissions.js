/**
 * Permissions config mapping roles to tables and allowed methods.
 * Operations map to HTTP Methods:
 * READ -> GET
 * CREATE -> POST
 * UPDATE -> PUT/PATCH
 * DELETE -> DELETE
 *
 * * means all permissions for that table
 * Array means specific methods allowed
 */

const permissionsMapping = {
  ADMIN: {
    '*': ['GET', 'POST', 'PUT', 'DELETE'] // Access all tables
  },
  GERENTE: {
    '*': ['GET', 'POST', 'PUT', 'DELETE'] // Full control
  },
  MESERO: {
    'mesa': ['GET', 'PUT'],
    'cliente': ['GET', 'POST', 'PUT'],
    'reservacion': ['GET', 'POST', 'PUT'],
    'orden': ['GET', 'POST'],
    'orden_detalle': ['GET', 'POST', 'PUT'],
    'categoria_menu': ['GET'], // Solo lectura
    'platillo': ['GET'] // Solo lectura
  },
  RECEPCIONISTA: { // NOT in DB roles strictly added, but from original DB SQL: 'GRANT SELECT, INSERT, UPDATE ON reservacion TO recepcionista_role;'
    'reservacion': ['GET', 'POST', 'PUT'],
    'mesa': ['GET'],
    'cliente': ['GET', 'POST', 'PUT']
  },
  COCINA: {
    'orden': ['GET'],
    'orden_detalle': ['GET', 'PUT'], // can update to LISTO
    'receta_ingrediente': ['GET'],
    'categoria_menu': ['GET'],
    'platillo': ['GET']
  },
  CAJERO: {
    'orden': ['GET', 'PUT'],
    'orden_detalle': ['GET'],
    'pago': ['GET', 'POST'],
    'cliente': ['GET'],
    'mesa': ['PUT']
  }
};

module.exports = permissionsMapping;
