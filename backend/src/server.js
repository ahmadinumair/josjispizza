const createApp = require('./app');

const port = Number(process.env.PORT) || 3000;
const app = createApp();

app.listen(port, '0.0.0.0', () => {
  console.log(`Josjis Pizza API berjalan di http://localhost:${port}`);
});
