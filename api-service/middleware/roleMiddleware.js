const permissions = require('../config/permissions');

module.exports = (req, res, next) => {
  const userRole = req.user.rol; // From authMiddleware
  const table = req.params.table; // URL contains the table
  const method = req.method; // 'GET', 'POST', 'PUT', 'DELETE'

  console.log(`Checking permissions for role: ${userRole}, table: ${table}, method: ${method}`);

  // Fetch the role config
  const roleConfig = permissions[userRole];

  if (!roleConfig) {
    return res.status(403).json({ error: 'El rol no existe o no tiene configuración de permisos' });
  }

  // Admin/Gerente catch-all check
  if (roleConfig['*'] && roleConfig['*'].includes(method)) {
    return next();
  }

  // Check specific table access
  const tableConfig = roleConfig[table];

  if (!tableConfig) {
    // If there is NO config for this table, that means NO ACCESS
    return res.status(403).json({ error: 'El rol no tiene permisos para acceder a esta tabla' });
  }

  // Check if role has method access on table
  if (!tableConfig.includes(method)) {
    return res.status(403).json({ error: `El rol no tiene permiso para realizar operaciones ${method} en esta tabla` });
  }

  // If we passed the filters, proceed
  next();
};
