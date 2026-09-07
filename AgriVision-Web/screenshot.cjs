const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  
  // Log all console messages
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  page.on('pageerror', error => console.log('PAGE ERROR:', error.message));
  page.on('requestfailed', request => console.log('REQ FAILED:', request.url(), request.failure().errorText));

  // Bypass auth by setting localStorage before navigation
  await page.evaluateOnNewDocument(() => {
    // If the app relies on indexedDB or specific localStorage for auth, this might not be enough.
    // However, our fake AuthContext currently forces a login.
  });

  await page.goto('http://localhost:5175');
  
  // Wait a few seconds for map to load
  await new Promise(r => setTimeout(r, 10000));
  
  // Take screenshot
  await page.screenshot({ path: '/Users/ahmad/.gemini/antigravity-ide/brain/fa993b0c-3ad3-4c32-9f37-ccf10ea66caf/map_screenshot.png' });
  
  // Check if canvas exists
  const canvasCount = await page.evaluate(() => document.querySelectorAll('canvas.maplibregl-canvas').length);
  console.log('CANVAS COUNT:', canvasCount);

  await browser.close();
})();
