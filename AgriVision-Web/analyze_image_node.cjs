const Jimp = require('jimp');

async function analyze() {
  const image = await Jimp.read('/Users/ahmad/.gemini/antigravity-ide/brain/fa993b0c-3ad3-4c32-9f37-ccf10ea66caf/map_screenshot_login.png');
  const width = image.bitmap.width;
  const height = image.bitmap.height;
  console.log(`Image size: ${width}x${height}`);

  const colors = new Set();
  for (let x = 0; x < width; x += 10) {
    for (let y = 0; y < height; y += 10) {
      colors.add(image.getPixelColor(x, y));
    }
  }
  
  console.log(`Unique colors in grid: ${colors.size}`);
  if (colors.size < 50) {
    console.log("WARNING: Image appears to be mostly solid colors (blank or error screen)");
  } else {
    console.log("Image contains varied colors (looks like a map or complex UI)");
  }

  const map_colors = new Set();
  let blank_pixels = 0;
  let total_pixels = 0;
  
  for (let x = Math.floor(width * 0.4); x < Math.floor(width * 0.8); x += 5) {
    for (let y = Math.floor(height * 0.4); y < Math.floor(height * 0.8); y += 5) {
      total_pixels++;
      const hex = image.getPixelColor(x, y);
      map_colors.add(hex);
      
      const rgba = Jimp.intToRGBA(hex);
      if (rgba.r > 230 && rgba.g > 230 && rgba.b > 230) {
        blank_pixels++;
      }
    }
  }
  
  console.log(`Unique colors in map region: ${map_colors.size}`);
  console.log(`Blank/White pixels in map region: ${blank_pixels} / ${total_pixels}`);
}

analyze().catch(console.error);
