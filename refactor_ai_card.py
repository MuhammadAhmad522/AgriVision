import re

with open("AgriVision/Features/Dashboard/Views/Components/AIAdvisorCard.swift", "r") as f:
    content = f.read()

replacements = {
    "AppColors.charcoalGreen": "Theme.Colors.primary",
    "AppColors.mediumGreen": "Theme.Colors.primaryMedium",
    "AppColors.limeGreen": "Theme.Colors.primaryLight",
    "AppColors.cream": "Theme.Colors.background",
    "AppColors.warningOrange": "Theme.Colors.warning"
}

for old, new in replacements.items():
    content = content.replace(old, new)

font_regex = re.compile(r'\.font\(\.system\(size:\s*(\d+)(?:,\s*weight:\s*\.([a-zA-Z]+))?(?:,\s*design:\s*\.[a-zA-Z]+)?\)\)')

def font_replacer(match):
    size = int(match.group(1))
    weight = match.group(2)
    
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

content = font_regex.sub(font_replacer, content)

replacements_std = {
    ".font(.subheadline.bold())": ".textStyle(.bodyStrong)",
    ".font(.caption)": ".textStyle(.caption)",
    ".font(.caption.bold())": ".textStyle(.captionStrong)",
    ".font(.caption2)": ".textStyle(.caption)",
    ".font(.largeTitle)": ".textStyle(.display)",
    ".font(.headline)": ".textStyle(.bodyStrong)",
    ".font(.subheadline)": ".textStyle(.body)"
}

for old, new in replacements_std.items():
    content = content.replace(old, new)

with open("AgriVision/Features/Dashboard/Views/Components/AIAdvisorCard.swift", "w") as f:
    f.write(content)
print("Replaced AIAdvisorCard!")
