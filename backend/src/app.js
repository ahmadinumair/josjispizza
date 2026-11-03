const express = require('express');
const { randomUUID } = require('node:crypto');
const menu = require('./menu');

function createApp() {
  const app = express();
  const orders = [];

  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      return res.sendStatus(204);
    }

    next();
  });
  app.use(express.json({ limit: '20kb' }));

  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', name: 'Josjis Pizza API' });
  });

  app.get('/api/menu', (req, res) => {
    res.json(menu);
  });

  app.post('/api/orders', (req, res) => {
    const { name, phone, address, items } = req.body ?? {};
    const customer = {
      name: typeof name === 'string' ? name.trim() : '',
      phone: typeof phone === 'string' ? phone.trim() : '',
      address: typeof address === 'string' ? address.trim() : '',
    };

    if (!customer.name || !customer.phone || !customer.address) {
      return res.status(400).json({
        error: 'Nama, nomor telepon, dan alamat wajib diisi.',
      });
    }

    if (
      customer.name.length > 100 ||
      customer.phone.length > 30 ||
      customer.address.length > 300
    ) {
      return res.status(400).json({ error: 'Data pelanggan terlalu panjang.' });
    }

    if (!Array.isArray(items) || items.length === 0 || items.length > menu.length) {
      return res.status(400).json({ error: 'Pesanan harus berisi item menu.' });
    }

    const normalizedItems = [];
    for (const item of items) {
      const product = menu.find((entry) => entry.id === item?.productId);
      if (
        !product ||
        !Number.isInteger(item.quantity) ||
        item.quantity < 1 ||
        item.quantity > 20 ||
        normalizedItems.some((entry) => entry.productId === product.id)
      ) {
        return res.status(400).json({ error: 'Item pesanan tidak valid.' });
      }

      normalizedItems.push({
        productId: product.id,
        name: product.name,
        quantity: item.quantity,
        unitPrice: product.price,
        subtotal: product.price * item.quantity,
      });
    }

    const order = {
      id: randomUUID(),
      customer,
      items: normalizedItems,
      total: normalizedItems.reduce((sum, item) => sum + item.subtotal, 0),
      status: 'Diterima',
      createdAt: new Date().toISOString(),
    };
    orders.push(order);

    res.status(201).json(order);
  });

  app.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'Format JSON tidak valid.' });
    }
    if (err.type === 'entity.too.large') {
      return res.status(413).json({ error: 'Data pesanan terlalu besar.' });
    }

    console.error(err);
    res.status(500).json({ error: 'Terjadi kesalahan pada server.' });
  });

  return app;
}

module.exports = createApp;
