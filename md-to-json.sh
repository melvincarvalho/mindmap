#!/bin/bash

# Script to convert markdown file to JSON using markmap-cli
# Usage: ./md-to-json.sh <input.md> [output.json]

set -e  # Exit on any error

# Check if markmap-cli is installed
if ! command -v markmap &> /dev/null; then
    echo "Error: markmap-cli is not installed."
    echo "Please install it with: npm install -g markmap-cli"
    exit 1
fi

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input.md> [output.json]"
    echo "Example: $0 my-notes.md output.json"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE%.*}.json}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' does not exist."
    exit 1
fi

# Check if input file has .md extension
if [[ ! "$INPUT_FILE" =~ \.md$ ]]; then
    echo "Warning: Input file does not have .md extension. Proceeding anyway..."
fi

echo "Converting '$INPUT_FILE' to JSON format..."

# Create temporary directory for intermediate files
TEMP_DIR=$(mktemp -d)
TEMP_HTML="$TEMP_DIR/temp.html"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Generate markmap HTML file
echo "Step 1: Generating markmap HTML..."
markmap "$INPUT_FILE" --output "$TEMP_HTML" --no-open

# Extract the data from the generated HTML file
echo "Step 2: Extracting JSON data..."

# Use Node.js to extract the JSON data from the HTML file
node -e "
const fs = require('fs');

try {
    // Read the generated HTML file
    const htmlContent = fs.readFileSync('$TEMP_HTML', 'utf8');
    
    // Extract the JSON data from the script tag
    // Look for the pattern in the markmap function call
    const regex = /\)\(\(\) => window\.markmap,null,({.*?}),null\)/s;
    const match = htmlContent.match(regex);
    
    if (match && match[1]) {
        // Parse and pretty-print the JSON
        const jsonData = JSON.parse(match[1]);
        
        // Write the JSON to output file
        fs.writeFileSync('$OUTPUT_FILE', JSON.stringify(jsonData, null, 2));
        console.log('✓ JSON data extracted successfully');
    } else {
        // Fallback: try to extract from different patterns
        // Look for any JSON object in script tags
        const altRegex = /,({\"content\":.*?}),null\)/s;
        const altMatch = htmlContent.match(altRegex);
        
        if (altMatch && altMatch[1]) {
            const jsonData = JSON.parse(altMatch[1]);
            fs.writeFileSync('$OUTPUT_FILE', JSON.stringify(jsonData, null, 2));
            console.log('✓ JSON data extracted successfully (alternative method)');
        } else {
            // Last resort: try to find any large JSON object
            const jsonRegex = /{\"content\":\"[^\"]*\",\"children\":\[.*?\]}/s;
            const jsonMatch = htmlContent.match(jsonRegex);
            
            if (jsonMatch && jsonMatch[0]) {
                const jsonData = JSON.parse(jsonMatch[0]);
                fs.writeFileSync('$OUTPUT_FILE', JSON.stringify(jsonData, null, 2));
                console.log('✓ JSON data extracted successfully (fallback method)');
            } else {
                console.error('Could not find JSON data in the generated HTML file');
                console.error('HTML content preview:');
                console.error(htmlContent.substring(0, 500) + '...');
                process.exit(1);
            }
        }
    }
} catch (error) {
    console.error('Error processing file:', error.message);
    process.exit(1);
}
"

# Verify the output file was created
if [ -f "$OUTPUT_FILE" ]; then
    echo "✓ Conversion completed successfully!"
    echo "Output file: $OUTPUT_FILE"
    echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    
    # Show a preview of the JSON structure
    echo ""
    echo "Preview of JSON structure:"
    echo "=========================="
    head -20 "$OUTPUT_FILE"
    if [ $(wc -l < "$OUTPUT_FILE") -gt 20 ]; then
        echo "..."
        echo "(showing first 20 lines)"
    fi
else
    echo "Error: Output file was not created."
    exit 1
fi 