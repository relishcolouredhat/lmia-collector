# LMIA Data Collector

<div align="center">
  <img src="docs_src/canada_flag.svg" alt="Flag of Canada" width="200" height="150">
</div>

## ⚠️ **Important Disclaimer**

**This is a PERSONAL, NON-GOVERNMENTAL initiative created by klc.**

- 🚫 **NOT affiliated with, endorsed by, or connected to the Government of Canada**
- 🚫 **NOT an official government tool or service**
- ✅ **Uses only publicly available open data** from Government of Canada sources
- ✅ **Personal, non-commercial, non-political open data project**

This tool processes and presents publicly available Labour Market Impact Assessment (LMIA) data to make it more accessible and easier to analyze. The data source is the Government of Canada's open data portal, but this tool itself is completely independent.

---

## About This Project

In August 2025, there is a ton of discussion going on about the LMIA program, so I'm looking to better understand it. 

This repo is intended to make it easier to consume publicly available data, to bring more data to the discussion. 

### What This Tool Does

- **Fetches LMIA data** from Government of Canada open data sources
- **Processes and converts** data into accessible CSV format
- **Provides web interface** for easy data exploration
- **Generates API endpoints** for integration with other tools
- **Automates updates** via GitHub Actions workflow

### Data Sources

All data comes from the [Government of Canada Open Data Portal](https://open.canada.ca/), specifically:
- LMIA positive reports (approved applications)
- LMIA negative reports (rejected applications)

This is **publicly available open data** that anyone can access and use.

---

## Features

### 🔄 **Automated Data Collection**
- GitHub Actions workflow runs on schedule
- Automatically fetches new LMIA reports
- Processes XLSX files to CSV format
- Removes administrative notes for cleaner data

### 🌐 **Web Interface**
- Modern, responsive web UX hosted on GitHub Pages
- Interactive data browser with tabbed interface
- Real-time statistics and data overview
- Direct CSV download links
- Grafana Infinity plugin compatibility

### 📊 **Data Organization**
- Structured output directory (`outputs/csv/positive`, `outputs/csv/negative`)
- JSON endpoint files for API access
- Language filtering (English/French)
- Automated file naming with dates

### 🚀 **Easy Integration**
- RESTful API endpoints
- Grafana Infinity plugin support
- CSV format for spreadsheet analysis
- GitHub Pages hosting for accessibility

---

## Technical Details

### **Architecture**
- **Data Collection**: Automated GitHub Actions workflow
- **Processing**: Shell scripts with csvkit for XLSX conversion
- **Web Interface**: Vanilla JavaScript, modern CSS, responsive design
- **Hosting**: GitHub Pages with automatic deployment
- **Storage**: Git-tracked CSV files with structured organization

### **Dependencies**
- `csvkit` - Lightweight XLSX to CSV conversion
- `jq` - JSON processing
- `curl` - Data fetching
- Modern web standards (ES6+, CSS Grid, Flexbox)

### **Workflow**
1. **Scheduled Run**: GitHub Actions workflow runs automatically
2. **Data Fetch**: Downloads new LMIA reports from Open Canada
3. **Processing**: Converts XLSX to CSV, removes notes, organizes files
4. **Deployment**: Updates repository and deploys to GitHub Pages
5. **Web Interface**: Automatically reflects new data

---

## Usage

### **Web Interface**
Visit the live site: [https://relishcolouredhat.github.io/lmia-collector/](https://relishcolouredhat.github.io/lmia-collector/)

### **API Endpoints**
- **Positive Reports**: `outputs/positive_endpoints.json`
- **Negative Reports**: `outputs/negative_endpoints.json`
- **All Endpoints**: `outputs/all_endpoints.json`

### **Manual Workflow Trigger**
1. Go to Actions tab in this repository
2. Select "Process LMIA Data" workflow
3. Click "Run workflow"
4. Choose language (English/French) and run

---

## Project Structure

```
lmia-collector/
├── .github/workflows/
│   ├── process_lmia.yml      # Main data processing workflow
│   └── deploy-pages.yml      # GitHub Pages deployment
├── scripts/
│   └── process_feeds.sh      # Data processing script
├── docs_src/
│   ├── styles.css            # Web interface styling
│   ├── app.js                # Web interface functionality
│   └── canada_flag.svg       # Canadian flag asset
├── outputs/                  # Generated data files
│   ├── csv/
│   │   ├── positive/         # Positive LMIA reports
│   │   └── negative/         # Negative LMIA reports
│   └── iflp/                 # Future Influx Line Protocol output
├── index.html                # Web interface main page
└── README.md                 # This file
```

---

## Development

### **Local Setup**
```bash
git clone https://github.com/relishcolouredhat/lmia-collector.git
cd lmia-collector
```

### **Testing Web Interface**
```bash
# Serve locally (requires Python or similar)
python -m http.server 8000
# Then visit http://localhost:8000
```

### **Running Workflow Locally**
```bash
# Test the processing script
LANGUAGE=en bash ./scripts/process_feeds.sh
```

---

## Contributing

This is a personal project, but contributions are welcome! Please note:

1. **This is NOT a government project** - it's a personal initiative
2. **All code contributions** will be attributed to LLM agents (see below)
3. **Focus on open data** and public information only
4. **Respect data privacy** and use only publicly available information

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## LLM Code Attribution

**Important Note**: This repository contains code that was generated with assistance from Large Language Models (LLMs). We want to be completely transparent about this:

### **What This Means:**
- **LLM-generated code cannot be owned** - it's inherently open source
- **All code here is open source** and available for anyone to use
- **We thank the original authors** whose code was used to train these models
- **This transparency** ensures ethical use of AI-generated code

### **Our Commitment:**
- **Full attribution** to LLM assistance where applicable
- **Open source licensing** for all generated code
- **Transparency** about AI involvement in development
- **Respect for original authors** whose work contributed to the training data

### **Why This Matters:**
- **Ethical AI use** requires transparency
- **Open source** ensures accessibility and collaboration
- **Proper attribution** respects intellectual property
- **Community trust** through honest disclosure

---

## Contact & Support

- **Creator**: klc
- **Repository**: [https://github.com/relishcolouredhat/lmia-collector](https://github.com/relishcolouredhat/lmia-collector)
- **Live Site**: [https://relishcolouredhat.github.io/lmia-collector/](https://relishcolouredhat.github.io/lmia-collector/)
- **Issues**: Use GitHub Issues for bug reports or feature requests

---

## Final Note

This tool exists to make government open data more accessible and useful. It's built with transparency, uses only public information, and is completely independent of any government entity. The goal is to contribute to public understanding and discussion of LMIA data through better data accessibility and visualization.

**Remember**: This is a personal project using public data - not an official government service.