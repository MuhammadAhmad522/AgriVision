import re

with open("AgriVision/Features/Dashboard/Views/DashboardView.swift", "r") as f:
    content = f.read()

replacements = {
    ".font(.subheadline.bold())": ".textStyle(.bodyStrong)",
    ".font(.caption)": ".textStyle(.caption)",
    ".font(.caption.bold())": ".textStyle(.captionStrong)",
    ".font(.caption2)": ".textStyle(.caption)",
    ".font(.largeTitle)": ".textStyle(.display)",
    ".font(.headline)": ".textStyle(.bodyStrong)",
    ".font(.subheadline)": ".textStyle(.body)"
}

for old, new in replacements.items():
    content = content.replace(old, new)

with open("AgriVision/Features/Dashboard/Views/DashboardView.swift", "w") as f:
    f.write(content)
print("Replaced standard fonts!")
