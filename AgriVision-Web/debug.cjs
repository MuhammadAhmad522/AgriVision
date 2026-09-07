const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  
  const logs = [];
  page.on('console', msg => {
    logs.push(`[CONSOLE ${msg.type().toUpperCase()}] ${msg.text()}`);
  });
  page.on('pageerror', error => {
    logs.push(`[PAGE ERROR] ${error.message}`);
  });
  page.on('requestfailed', request => {
    logs.push(`[REQ FAILED] ${request.url()} - ${request.failure().errorText}`);
  });

  // Enable request interception to mock auth and fields API
  await page.setRequestInterception(true);
  
  page.on('request', request => {
    const url = request.url();
    // Intercept API calls if they happen
    if (url.includes('/api/fields')) {
      request.respond({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'mock-1',
            owner_id: 'mock-owner',
            name: 'Mock Field',
            crop_type: 'Wheat',
            area_ha: 10,
            plantation_date: '2025-01-01',
            coordinates: [
              { lat: 39.8, lng: -98.5 },
              { lat: 39.81, lng: -98.5 },
              { lat: 39.81, lng: -98.49 },
              { lat: 39.8, lng: -98.49 },
            ],
            status: 'active'
          }
        ])
      });
    } else {
      request.continue();
    }
  });

  // We need to bypass auth in the app code directly or here.
  // Actually, let's just temporarily patch App.tsx from bash before running this, to render GISMapView without auth.
  
  await page.goto('http://localhost:5175');
  
  // Wait a bit
  await new Promise(r => setTimeout(r, 6000));
  
  const fs = require('fs');
  fs.writeFileSync('puppeteer_logs.txt', logs.join('\n'));
  console.log('Logs written to puppeteer_logs.txt');
  
  await browser.close();
})();
