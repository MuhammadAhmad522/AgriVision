const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  
  const logs = [];

  page.on('response', async (res) => {
    if (res.url().includes('/api/fields')) {
      try {
        const json = await res.json();
        logs.push(`[API] /fields response: ${JSON.stringify(json).slice(0, 500)}`);
      } catch (e) {}
    }
  });

  page.on('console', msg => {
    logs.push(`[CONSOLE ${msg.type().toUpperCase()}] ${msg.text()}`);
  });
  page.on('pageerror', error => {
    logs.push(`[PAGE ERROR] ${error.message}`);
  });
  page.on('requestfailed', request => {
    logs.push(`[REQ FAILED] ${request.url()} - ${request.failure().errorText}`);
  });

  try {
    await page.goto('http://localhost:5173');
    await page.waitForSelector('input[type="email"]', { timeout: 10000 });
    
    // Fill login
    await page.type('input[type="email"]', 'muhammadahmad522@gmail.com');
    await page.type('input[type="password"]', 'Password@123');
    
    // Click submit
    await page.click('button[type="submit"]');
    
    // Wait for navigation and dashboard load
    await new Promise(r => setTimeout(r, 5000));

    // Take a screenshot of the main page to see what's rendering
    await page.screenshot({ path: '/Users/ahmad/.gemini/antigravity-ide/brain/fa993b0c-3ad3-4c32-9f37-ccf10ea66caf/map_screenshot_login.png' });
    
    // Check canvas existence and size
    const canvasInfo = await page.evaluate(() => {
      const canvas = document.querySelector('canvas.maplibregl-canvas');
      if (!canvas) return null;
      const rect = canvas.getBoundingClientRect();
      return { width: rect.width, height: rect.height, display: window.getComputedStyle(canvas).display };
    });
    logs.push(`[SYSTEM] CANVAS INFO: ${JSON.stringify(canvasInfo)}`);
    
  } catch (err) {
    logs.push(`[SCRIPT ERROR] ${err.message}`);
  }

  fs.writeFileSync('puppeteer_logs.txt', logs.join('\n'));
  console.log('Logs written to puppeteer_logs.txt');
  
  await browser.close();
})();
