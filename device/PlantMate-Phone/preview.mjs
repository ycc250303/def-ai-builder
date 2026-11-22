import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { networkInterfaces } from 'node:os';

const page = await readFile(new URL('./index.html', import.meta.url));
const started = Date.now();
const port = Number(process.env.PLANTMATE_PORT || 8790);
const host = process.argv.includes('--lan') ? '0.0.0.0' : '127.0.0.1';

http.createServer((request, response) => {
  const path = request.url?.split('?')[0];
  const headers = { 'Cache-Control': 'no-store' };
  if (request.method !== 'GET') {
    response.writeHead(405, { ...headers, Allow: 'GET' }).end();
  } else if (path === '/') {
    response.writeHead(200, { ...headers, 'Content-Type': 'text/html; charset=utf-8' }).end(page);
  } else if (path === '/api/state') {
    const sequence = Math.floor((Date.now() - started) / 1000) + 1;
    const cycle = Math.floor((sequence - 1) / 6);
    const commands = ['MONITORING', 'CHECK_SOIL', 'TOUCH_DETECTED'];
    const phase = cycle % commands.length;
    response.writeHead(200, { ...headers, 'Content-Type': 'application/json; charset=utf-8' }).end(JSON.stringify({
      source: 'simulation', sequence,
      sensors: {
        temperature_c: 24 + Math.sin(sequence / 5),
        humidity_rh: 62 + 3 * Math.sin(sequence / 8),
        light_lux: 450 + 70 * Math.sin(sequence / 4),
        soil_level: phase === 1 ? 'high' : 'low',
        touch_mask: phase === 2 ? 5 : 0
      },
      command: { id: cycle + 1, code: commands[phase] }
    }));
  } else {
    response.writeHead(404, headers).end();
  }
}).listen(port, host, () => {
  console.log('http://127.0.0.1:' + port + '/');
  if (host === '0.0.0.0') {
    for (const addresses of Object.values(networkInterfaces())) {
      for (const address of addresses ?? []) {
        if (address.family === 'IPv4' && !address.internal) console.log('LAN http://' + address.address + ':' + port + '/');
      }
    }
  }
});
