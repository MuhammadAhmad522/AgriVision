import os
import pypandoc

input_file = "AgriVision_SRS.md"
output_file = "AgriVision_SRS.docx"

print("Downloading pandoc...")
pypandoc.download_pandoc()
print("Converting to DOCX...")
pypandoc.convert_file(input_file, 'docx', outputfile=output_file)
print("Successfully generated DOCX!")
