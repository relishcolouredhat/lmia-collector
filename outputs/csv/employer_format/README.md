# Employer Format LMIA Data

This directory contains LMIA (Labour Market Impact Assessment) data files in the **employer format**, which is a simplified structure used for certain historical reports.

## Data Format

### **File Structure**
Each CSV file contains the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| **Employer** | Company or organization name | "Aker Solutions AIM" |
| **Address** | Full address including postal code | "215 Water Street, Box 20, Suite 511, St. John's, NL A1C 6C9" |
| **Positions approved** | Number of positions approved | "3" |
| **Postal Code** | Extracted postal code | "A1C 6C9" |

### **Data Characteristics**
- **Format**: Simple, flat structure
- **Scope**: Employer-focused view
- **Time Period**: Historical data (2015-2016)
- **Language**: English only
- **Geographic Coverage**: Canada-wide

## File Naming Convention

Files follow this pattern:
```
YYYY-MM-DD_original_filename.csv
```

Example:
- `2016-10-21_2015_positive_employers_en.csv`
- `2016-10-21_positive_employers_en.csv`

## Data Source

All data originates from the [Government of Canada Open Data Portal](https://open.canada.ca/):
- **Feed ID**: `90fed587-1364-4f33-a9ee-208181dc0b97` (Positive LMIA)
- **Feed ID**: `f82f66f2-a22b-4511-bccf-e1d74db39ae5` (Negative LMIA)

## Processing Notes

### **Postal Code Extraction**
- Postal codes are automatically extracted from the Address column
- Uses regex pattern matching for Canadian postal codes (A1A 1A1 format)
- Empty postal code field if no valid code is found

### **Data Cleaning**
- Administrative notes and footers are removed
- Headers are standardized
- Empty rows are filtered out

## Usage Examples

### **Basic Analysis**
```bash
# Count total positions approved
awk -F',' 'NR>1 {sum+=$3} END {print "Total positions:", sum}' filename.csv

# Find employers in specific province
grep "NL" filename.csv | cut -d',' -f1,3
```

### **Postal Code Analysis**
```bash
# Count positions by postal code
cut -d',' -f4 filename.csv | sort | uniq -c | sort -nr
```

## Data Quality Notes

- **Completeness**: Some addresses may not contain valid postal codes
- **Accuracy**: Data is as provided by the Government of Canada
- **Timeliness**: Historical data, not real-time
- **Coverage**: Limited to specific time periods and report types

## Integration

### **Grafana Infinity Plugin**
Use the endpoint file: `../employer_format_endpoints.json`

### **API Access**
Direct CSV access via GitHub raw URLs:
```
https://raw.githubusercontent.com/relishcolouredhat/lmia-collector/main/outputs/csv/employer_format/filename.csv
```

## Related Data

- **Quarterly Format**: See `../quarterly_format/` for more recent, detailed data
- **Combined Endpoints**: See `../all_endpoints.json` for all available data sources

---

**Note**: This is processed open data from the Government of Canada. This tool is a personal initiative and is not affiliated with any government entity.
