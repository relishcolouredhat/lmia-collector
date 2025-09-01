# LMIA Data Collector

## 🎯 **What This Repository Does**

This repository automatically collects, processes, and presents Labour Market Impact Assessment (LMIA) data from the Government of Canada's Open Data Portal. Here's how it works:

### **🔄 Automated Data Collection**
- **Daily Monitoring**: Automatically checks for new LMIA reports every day via GitHub Actions
- **Real-time Updates**: Detects and downloads new data as soon as it becomes available
- **Language Filtering**: Configurable to process English or French language reports

### **📊 Data Processing & Enhancement**
- **Format Conversion**: Converts Excel (.xlsx) files to CSV format for better compatibility
- **Data Cleaning**: Removes administrative notes and footers while preserving all data
- **Smart Organization**: Automatically separates different data formats into appropriate directories
- **Postal Code Extraction**: Automatically extracts Canadian postal codes from address fields
- **Geographic Coordinates**: Adds latitude/longitude coordinates for each postal code using OpenStreetMap geocoding

### **🔍 Data Quality & Integrity**
- **No Data Synthesis**: We do NOT generate, create, or synthesize any data during processing
- **Pure Transformation**: All processing is purely mechanical transformation of existing government data
- **Geocoding Only**: The only external data we add is geographic coordinates from postal codes
- **Source Preservation**: Original data structure and content is preserved exactly as provided

### **📁 Output Organization**
- **Employer Format**: Historical data (2015-2016) with simple employer-focused structure
- **Quarterly Format**: Recent data (2017-2025) with comprehensive provincial and occupational breakdowns
- **Structured Directories**: Organized by format type for easy analysis and integration

---

<div align="center">
  <img src="docs_src/canada_flag.svg" alt="Flag of Canada" width="200" height="150">
</div>

## ⚠️ **Important Disclaimer**

**This is a PERSONAL, NON-GOVERNMENTAL initiative created by klc.**

- 🚫 **NOT affiliated with, endorsed by, or connected to the Government of Canada**
- 🚫 **NOT an official government tool or service**
- ✅ **Uses only publicly available open data** from Government of Canada sources
- ✅ **Personal, non-commercial, non-political open data project**

## 🚀 **Key Features**

- **Automated Data Collection**: Daily monitoring via GitHub Actions
- **Format Conversion**: Excel to CSV conversion for better compatibility
- **Data Enhancement**: Postal code extraction and geographic coordinates
- **Smart Organization**: Automatic format detection and directory organization
- **API Endpoints**: JSON endpoints for Grafana Infinity plugin integration
- **Web Interface**: User-friendly web UX hosted on GitHub Pages
- **Open Source**: MIT licensed and fully transparent

## 📊 **Data Sources**

All data originates from the [Government of Canada Open Data Portal](https://open.canada.ca/):

- **Positive LMIA Feed**: `90fed587-1364-4f33-a9ee-208181dc0b97`
- **Negative LMIA Feed**: `f82f66f2-a22b-4511-bccf-e1d74db39ae5`

## 🔧 **Technical Implementation**

- **Automation**: GitHub Actions workflow with daily scheduled runs
- **Processing**: Bash scripts for data extraction and transformation
- **Geocoding**: OpenStreetMap Nominatim service for postal code coordinates
- **Web Interface**: Vanilla HTML/CSS/JavaScript with responsive design
- **Deployment**: Automatic GitHub Pages deployment via GitHub Actions

## 📈 **Data Processing Pipeline**

1. **Daily Check**: GitHub Actions workflow runs automatically
2. **Feed Monitoring**: Checks both positive and negative LMIA feeds
3. **Language Filtering**: Processes only specified language (en/fr)
4. **Format Detection**: Automatically identifies data format type
5. **Data Download**: Downloads new files from government sources
6. **Format Conversion**: Converts Excel to CSV if needed
7. **Data Cleaning**: Removes administrative notes and footers
8. **Postal Code Extraction**: Extracts postal codes using regex patterns
9. **Geocoding**: Retrieves coordinates from OpenStreetMap service
10. **Organization**: Places files in appropriate format directories
11. **Endpoint Generation**: Creates JSON endpoints for API access
12. **Web Update**: Updates web interface with new data

## 🌍 **Geocoding Implementation**

### **How It Works**
- **Postal Code Extraction**: Uses regex patterns to find Canadian postal codes in address fields
- **Coordinate Retrieval**: Sends postal codes to OpenStreetMap Nominatim geocoding service
- **Rate Limiting**: Respects API limits (1 request per second)
- **Data Addition**: Adds latitude and longitude columns to CSV files

### **What We Add**
- **Latitude Column**: Geographic latitude coordinate
- **Longitude Column**: Geographic longitude coordinate

### **What We DON'T Add**
- No synthetic data
- No generated content
- No AI-generated information
- No modified government data

### **Data Integrity**
- All original government data is preserved exactly as provided
- Only geographic coordinates are added as additional columns
- No existing data is modified, removed, or synthesized

## 📚 **Data Formats**

### **Employer Format (2015-2016)**
Simple structure with employer, address, and positions approved:
```csv
Employer,Address,Positions approved,Postal Code,Latitude,Longitude
```

### **Quarterly Format (2017-2025)**
Comprehensive structure with province, stream, occupation, and detailed breakdowns:
```csv
Province/Territory,Stream,Employer,Address,Occupations under NOC 2011,Positions Approved,Postal Code,Latitude,Longitude
```

## 🛠️ **Usage**

### **Manual Workflow Trigger**
```bash
# Trigger data collection manually
gh workflow run process_lmia.yml
```

### **Local Processing**
```bash
# Process data locally
LANGUAGE=en bash ./scripts/process_feeds.sh
```

### **Web Interface**
Visit the [web interface](https://relishcolouredhat.github.io/lmia-collector/) for:
- Data overview and statistics
- File browsing by format
- Direct CSV downloads
- API endpoint access

## 🔗 **API Endpoints**

- **Employer Format**: `outputs/employer_format_endpoints.json`
- **Quarterly Format**: `outputs/quarterly_format_endpoints.json`
- **Combined**: `outputs/all_endpoints.json`

## 📄 **License**

This project is open source under the [MIT License](LICENSE).

## 🤝 **Contributing**

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 🙏 **Acknowledgments**

- **Government of Canada**: For providing open data through the Open Data Portal
- **OpenStreetMap**: For providing free geocoding services via Nominatim
- **GitHub**: For hosting and providing GitHub Actions automation
- **Open Source Community**: For the tools and libraries that make this project possible

---

## 🌍 **Geocoding Service Attribution**

### **OpenStreetMap Nominatim Service**
This project uses the **OpenStreetMap Nominatim geocoding service** to convert Canadian postal codes to geographic coordinates (latitude/longitude). 

**What We Use:**
- **Service**: OpenStreetMap Nominatim API
- **Purpose**: Convert postal codes to geographic coordinates
- **Rate Limiting**: We respect the 1 request per second limit
- **Data Added**: Only latitude and longitude columns

**Why OpenStreetMap:**
- **Free and Open**: No cost for usage
- **Reliable**: Community-maintained geographic data
- **Accurate**: High-quality Canadian postal code coverage
- **Transparent**: Open data with clear usage terms

**Our Usage:**
- We extract postal codes from address fields using regex patterns
- We send postal codes to Nominatim service for coordinate lookup
- We add the resulting coordinates as new columns to our CSV files
- We do NOT store, cache, or redistribute the coordinate data

**Thank You OpenStreetMap Community:**
We are grateful to the OpenStreetMap community for providing this essential geocoding service that makes our geographic analysis possible. Your commitment to open geographic data enables projects like ours to add valuable location context to government datasets.

---

**Note**: This tool processes open data from the Government of Canada but is not affiliated with any government entity. All data processing is purely mechanical transformation with no synthesis or generation of new information.