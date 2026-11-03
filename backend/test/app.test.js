const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const createApp = require('../src/app');

let server;
let baseUrl;

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test('menu returns available pizzas', async () => {
  const response = await fetch(`${baseUrl}/api/menu`);
  const menu = await response.json();

  assert.equal(response.status, 200);
  assert.ok(menu.length > 0);
  assert.ok(menu.every((item) => item.id && item.price > 0));
});

test('order validates customer and calculates price on the server', async () => {
  const response = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: '  Ana  ',
      phone: '08123456789',
      address: 'Jl. Pizza 1',
      items: [{ productId: 'margherita', quantity: 2, price: 1 }],
    }),
  });
  const order = await response.json();

  assert.equal(response.status, 201);
  assert.equal(order.customer.name, 'Ana');
  assert.equal(order.total, 116000);
  assert.equal(order.items[0].unitPrice, 58000);
});

test('order rejects invalid items and missing customer data', async () => {
  const missingCustomer = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ items: [{ productId: 'margherita', quantity: 1 }] }),
  });
  const invalidItem = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'Ana',
      phone: '08123456789',
      address: 'Jl. Pizza 1',
      items: [{ productId: 'unknown-pizza', quantity: 1 }],
    }),
  });

  assert.equal(missingCustomer.status, 400);
  assert.equal(invalidItem.status, 400);
});
