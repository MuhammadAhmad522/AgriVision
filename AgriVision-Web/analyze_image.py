from PIL import Image
import sys

try:
    img = Image.open('/Users/ahmad/.gemini/antigravity-ide/brain/fa993b0c-3ad3-4c32-9f37-ccf10ea66caf/map_screenshot_login.png')
    img = img.convert('RGB')
    width, height = img.size
    
    print(f"Image size: {width}x{height}")
    
    # Check a grid of pixels to see if the screen is mostly a solid color
    colors = set()
    for x in range(0, width, 10):
        for y in range(0, height, 10):
            colors.add(img.getpixel((x, y)))
            
    print(f"Unique colors in grid: {len(colors)}")
    if len(colors) < 50:
        print("WARNING: Image appears to be mostly solid colors (blank or error screen)")
    else:
        print("Image contains varied colors (looks like a map or complex UI)")
        
    # Let's also check a region that should definitely be the map.
    # Assuming map is roughly in the center-right of the screen.
    map_colors = set()
    for x in range(int(width * 0.4), int(width * 0.8), 5):
        for y in range(int(height * 0.4), int(height * 0.8), 5):
            map_colors.add(img.getpixel((x, y)))
            
    print(f"Unique colors in map region: {len(map_colors)}")
    
    # Count how many pixels are exactly white or very light gray in the map region
    blank_pixels = 0
    total_pixels = 0
    for x in range(int(width * 0.4), int(width * 0.8), 5):
        for y in range(int(height * 0.4), int(height * 0.8), 5):
            total_pixels += 1
            r, g, b = img.getpixel((x, y))
            # MapLibre default background is often #e8e4e4 or white or transparent
            if r > 230 and g > 230 and b > 230:
                blank_pixels += 1
                
    print(f"Blank/White pixels in map region: {blank_pixels} / {total_pixels}")

except Exception as e:
    print(f"Error: {e}")
