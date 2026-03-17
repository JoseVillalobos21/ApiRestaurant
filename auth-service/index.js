const express = require('express');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Database connection
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASS,
  port: process.env.DB_PORT,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    // Check credentials (INSECURE PLAINTEXT just for demo purposes, as instructed by DB setup)
    const result = await pool.query(
      `SELECT e.empleado_id, e.nombre, e.email, e.password, r.nombre AS rol 
       FROM empleado e
       JOIN rol r ON e.rol_id = r.rol_id
       WHERE e.email = $1`,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Password check (plain text per the init.sql structure)
    if (user.password !== password) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT including the role
    const payload = {
      sub: user.empleado_id,
      email: user.email,
      nombre: user.nombre,
      rol: user.rol // ADMIN, GERENTE, MESERO, COCINA, CAJERO
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '8h' });

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.empleado_id,
        nombre: user.nombre,
        rol: user.rol
      }
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Auth service running on port ${PORT}`);
});
