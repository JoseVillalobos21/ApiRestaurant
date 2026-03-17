const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const authMiddleware = require('./middleware/authMiddleware');
const roleMiddleware = require('./middleware/roleMiddleware');

const app = express();
app.use(express.json());
app.use(cors());

// DB connection
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

// Utility function to check table name safely
const isValidTableName = (name) => {
  return /^[a-zA-Z_]+$/.test(name);
};

// GET ALL /api/:table
// All endpoints are dynamically checking permission using roleMiddleware!
app.get('/api/:table', authMiddleware, roleMiddleware, async (req, res) => {
  const { table } = req.params;

  if (!isValidTableName(table)) return res.status(400).json({ error: 'Invalid table name format' });

  try {
    const result = await pool.query(`SELECT * FROM ${table} ORDER BY 1 DESC LIMIT 50`);
    res.json(result.rows);
  } catch (err) {
    if (err.code === '42P01') {
      res.status(404).json({ error: `Table '${table}' not found` });
    } else {
      console.error(err);
      res.status(500).json({ error: 'Internal server error while fetching data' });
    }
  }
});

// GET ONE /api/:table/:id
app.get('/api/:table/:id', authMiddleware, roleMiddleware, async (req, res) => {
  const { table, id } = req.params;

  if (!isValidTableName(table)) return res.status(400).json({ error: 'Invalid table name format' });

  try {
    // We assume the Primary Key is `<table_name>_id` based on user schema
    // Need specifically to get the PK name, but as an heuristic:
    const pk_name = `${table}_id`;
    
    // As a simple workaround for generic service, we just try to guess the ID or use column index
    const result = await pool.query(`SELECT * FROM ${table} WHERE ${pk_name} = $1`, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Record not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error fetching record' });
  }
});

// POST /api/:table
app.post('/api/:table', authMiddleware, roleMiddleware, async (req, res) => {
  const { table } = req.params;

  if (!isValidTableName(table)) return res.status(400).json({ error: 'Invalid table name format' });

  const keys = Object.keys(req.body);
  const values = Object.values(req.body);

  if (keys.length === 0) return res.status(400).json({ error: 'No body provided' });

  const columns = keys.join(', ');
  const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');

  try {
    const query = `INSERT INTO ${table} (${columns}) VALUES (${placeholders}) RETURNING *`;
    const result = await pool.query(query, values);
    
    res.status(201).json({
      message: 'Record created successfully',
      record: result.rows[0]
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error inserting record. Make sure fields are correct.' });
  }
});

// START
const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`API Service dynamically exposing tables on port ${PORT}`);
});
