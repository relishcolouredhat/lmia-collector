# Quarterly Format LMIA Data

This directory contains LMIA (Labour Market Impact Assessment) data files in the **quarterly format**, which is the comprehensive structure used for recent reports and detailed analysis.

## Data Format

### **File Structure**
Each CSV file contains the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| **Province/Territory** | Canadian province or territory | "Newfoundland and Labrador" |
| **Stream** | LMIA stream category | "High Wage" |
| **Employer** | Company or organization name | "Arup Canada Inc." |
| **Address** | Full address including postal code | "St. John's, NL A1B 4M7" |
| **Occupations under NOC 2011** | National Occupational Classification code and title | "0211-Engineering managers" |
| **Positions Approved** | Number of positions approved | "1" |
| **Postal Code** | Extracted postal code | "A1B 4M7" |
| **Latitude** | Geographic latitude coordinate | "47.5615" |
| **Longitude** | Geographic longitude coordinate | "-52.7126" |

### **Data Characteristics**
- **Format**: Comprehensive, structured data
- **Scope**: Province, stream, and occupation-focused view
- **Time Period**: Recent data (2017-2025)
- **Language**: English and French versions available
- **Geographic Coverage**: Canada-wide with provincial breakdown
- **Update Frequency**: Quarterly (Q1, Q2, Q3, Q4)

## File Naming Convention

Files follow this pattern:
```
YYYY-MM-DD_tfwp_YYYYqX_pos_en.csv
```

Examples:
- `2024-06-20_tfwp_2024q1_pos_en.csv` (2024 Q1 Positive)
- `2024-10-24_tfwp_2024q2_pos_en.csv` (2024 Q2 Positive)
- `2024-12-20_tfwp_2024q3_pos_en.csv` (2024 Q3 Positive)
- `2025-03-18_tfwp_2024q4_pos_en.csv` (2024 Q4 Positive)

## Data Source

All data originates from the [Government of Canada Open Data Portal](https://open.canada.ca/):
- **Feed ID**: `90fed587-1364-4f33-a9ee-208181dc0b97` (Positive LMIA)
- **Feed ID**: `f82f66f2-a22b-4511-bccf-e1d74db39ae5` (Negative LMIA)

## Processing Notes

### **Postal Code and Coordinates Extraction**
- Postal codes are automatically extracted from the Address column
- Uses regex pattern matching for Canadian postal codes (A1A 1A1 format)
- Geographic coordinates (latitude/longitude) are automatically retrieved for each postal code
- Uses OpenStreetMap Nominatim geocoding service (free, rate-limited)
- Empty fields if no valid postal code or coordinates are found

### **Data Cleaning**
- Administrative notes and footers are removed
- Headers are standardized
- Empty rows are filtered out
- Provincial information is preserved

## Usage Examples

### **Basic Analysis**
```bash
# Count total positions approved by province
awk -F',' 'NR>1 {province[$1]+=$6} END {for(p in province) print p ": " province[p]}' filename.csv

# Find high-wage stream positions
awk -F',' 'NR>1 && $2 ~ /High Wage/ {print $3, $6}' filename.csv
```

### **Postal Code Analysis**
```bash
# Count positions by postal code
cut -d',' -f7 filename.csv | sort | uniq -c | sort -nr

# Find positions in specific postal code area
awk -F',' 'NR>1 && $7 ~ /^A1B/ {print $3, $5, $6}' filename.csv

# Find positions in specific geographic area
awk -F',' 'NR>1 && $8 != "" && $9 != "" {print $3, $7, $8, $9}' filename.csv
```

### **Occupational Analysis**
```bash
# Count positions by occupation
cut -d',' -f5 filename.csv | sort | uniq -c | sort -nr

# Find engineering positions
awk -F',' 'NR>1 && $5 ~ /engineering/i {print $3, $5, $6}' filename.csv
```

## Data Quality Notes

- **Completeness**: High - most records contain all required fields
- **Accuracy**: Data is as provided by the Government of Canada
- **Timeliness**: Recent data, updated quarterly
- **Coverage**: Comprehensive coverage of all provinces and territories
- **Consistency**: Standardized format across all quarterly reports

## Stream Categories

Common LMIA streams include:
- **High Wage**: Positions with wages above provincial median
- **Low Wage**: Positions with wages below provincial median
- **Global Talent Stream**: Specialized positions for high-growth companies
- **Agricultural Stream**: Agricultural and food processing positions

## Integration

### **Grafana Infinity Plugin**
Use the endpoint file: `../quarterly_format_endpoints.json`

### **API Access**
Direct CSV access via GitHub raw URLs:
```
https://raw.githubusercontent.com/relishcolouredhat/lmia-collector/main/outputs/csv/quarterly_format/filename.csv
```

## Related Data

- **Employer Format**: See `../employer_format/` for historical, simplified data
- **Combined Endpoints**: See `../all_endpoints.json` for all available data sources

## Analysis Capabilities

This format enables:
- **Geographic Analysis**: Provincial and postal code breakdowns
- **Temporal Analysis**: Quarterly trends and comparisons
- **Occupational Analysis**: NOC code-based categorization
- **Stream Analysis**: Policy impact assessment by stream
- **Employer Analysis**: Company-level position tracking

---

**Note**: This is processed open data from the Government of Canada. This tool is a personal initiative and is not affiliated with any government entity.
