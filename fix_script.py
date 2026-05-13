import sys
content = open("AgriVision/Features/Dashboard/Views/DashboardView.swift").read()
replacement = open("replacement.swift").read()

start_str = "struct MoistureCardView: View {"
end_str = "struct PHLevelCardView: View {"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

new_content = content[:start_idx] + replacement + "\n" + content[end_idx:]

with open("AgriVision/Features/Dashboard/Views/DashboardView.swift", "w") as f:
    f.write(new_content)
