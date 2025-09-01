# LMIA Data Explorer Web Interface

This directory contains the web interface for the LMIA Data Explorer, designed to be hosted on GitHub Pages.

## Files

- **`index.html`** - Main HTML structure
- **`styles.css`** - CSS styling and responsive design
- **`app.js`** - JavaScript functionality and data loading
- **`canada_flag.svg`** - Canadian flag asset

## Features

### 🎯 **Data Overview Dashboard**
- Real-time statistics on available reports
- Count of positive and negative LMIA reports
- Latest data update timestamp

### 📊 **Interactive Data Browser**
- Tabbed interface for positive/negative reports
- File listing with publication dates
- Direct CSV download links
- Responsive design for mobile devices

### 🔗 **API Endpoint Access**
- Direct links to JSON endpoint files
- Grafana Infinity plugin compatibility
- Easy integration with data visualization tools

## Technical Details

### **Framework**
- **Vanilla JavaScript** - No external dependencies
- **Modern CSS** - Grid, Flexbox, and CSS variables
- **Responsive Design** - Mobile-first approach

### **Data Loading**
- Fetches data from generated endpoint JSON files
- Automatic error handling and user feedback
- Real-time statistics updates

### **Performance**
- Lightweight and fast loading
- Minimal JavaScript footprint
- Optimized for GitHub Pages hosting

## Deployment

The web interface is automatically deployed to GitHub Pages via GitHub Actions:

1. **Automatic Deployment** - Triggers on pushes to main and feature branches
2. **GitHub Pages Integration** - Uses official GitHub Pages deployment actions
3. **Concurrent Deployment Protection** - Prevents deployment conflicts

## Customization

### **Styling**
- Modify `styles.css` to change colors, fonts, and layout
- CSS variables for easy theme customization
- Responsive breakpoints for different screen sizes

### **Functionality**
- Extend `app.js` to add new features
- Modify data loading logic in the `LMIADataExplorer` class
- Add new tabs or sections as needed

### **Data Integration**
- Update endpoint file paths in `app.js`
- Modify data parsing logic for different file formats
- Add new data sources as needed

## Browser Support

- **Modern Browsers** - Chrome, Firefox, Safari, Edge (latest versions)
- **Mobile Browsers** - iOS Safari, Chrome Mobile
- **JavaScript Required** - No fallback for disabled JavaScript

## Future Enhancements

- **Data Visualization** - Charts and graphs using Chart.js or D3.js
- **Search and Filtering** - Advanced data exploration tools
- **Export Options** - Multiple format support (JSON, XML)
- **Real-time Updates** - WebSocket integration for live data
