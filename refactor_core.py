import re
import os

files = [
    "AgriVision/Core/UI/ToastView.swift",
    "AgriVision/Core/UI/BackendConnectionView.swift",
    "AgriVision/Core/UI/ErrorView.swift"
]

replacements = {
    "AppColors.charcoalGreen": "Theme.Colors.primary",
    "AppColors.mediumGreen": "Theme.Colors.primaryMedium",
    "AppColors.limeGreen": "Theme.Colors.primaryLight",
    "AppColors.cream": "Theme.Colors.background",
    "AppColors.warningOrange": "Theme.Colors.warning"
}

font_regex = re.compile(r'\.font\(\.system\(size:\s*(\d+)(?:,\s*weight:\s*\.([a-zA-Z]+))?(?:,\s*design:\s*\.[a-zA-Z]+)?\)\)')

def font_replacer(match):
    size = int(match.group(1))
    weight = match.group(2) if match.group(2) else ""
    
    if size >= 40:
        return '.textStyle(.display)'
    elif size >= 28:
        return '.textStyle(.title1)'
    elif size >= 22:
        return '.textStyle(.title2)'
    elif size >= 18:
        if weight in ['bold', 'semibold']:
            return '.textStyle(.bodyStrong)'
        return '.textStyle(.body)'
    elif size >= 15:
        if weight in ['bold', 'semibold']:
            return '.textStyle(.bodyStrong)'
        return '.textStyle(.body)'
    else: # size < 15
        if weight in ['bold', 'semibold']:
            return '.textStyle(.captionStrong)'
        return '.textStyle(.caption)'

replacements_std = {
    ".font(.subheadline.bold())": ".textStyle(.bodyStrong)",
    ".font(.caption)": ".textStyle(.caption)",
    ".font(.caption.bold())": ".textStyle(.captionStrong)",
    ".font(.caption2)": ".textStyle(.caption)",
    ".font(.largeTitle)": ".textStyle(.display)",
    ".font(.headline)": ".textStyle(.bodyStrong)",
    ".font(.subheadline)": ".textStyle(.body)"
}

for filepath in files:
    if not os.path.exists(filepath):
        continue
    with open(filepath, "r") as f:
        content = f.read()

    for old, new in replacements.items():
        content = content.replace(old, new)
        
    content = font_regex.sub(font_replacer, content)
    
    for old, new in replacements_std.items():
        content = content.replace(old, new)

    with open(filepath, "w") as f:
        f.write(content)

print("Replaced across Core UI views!")
