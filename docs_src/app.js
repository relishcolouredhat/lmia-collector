// LMIA Data Explorer Web Application
class LMIADataExplorer {
    constructor() {
        this.init();
    }

    init() {
        this.setupTabSwitching();
        this.loadData();
        this.updateStats();
        this.updateCacheStats();
        this.updateLastRunInfo();
    }

    setupTabSwitching() {
        const tabBtns = document.querySelectorAll('.tab-btn');
        const tabContents = document.querySelectorAll('.tab-content');

        tabBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                const targetTab = btn.dataset.tab;
                
                // Update active tab button
                tabBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                
                // Update active tab content
                tabContents.forEach(content => {
                    content.classList.remove('active');
                    if (content.id === `${targetTab}-content`) {
                        content.classList.add('active');
                    }
                });
            });
        });
    }

    async loadData() {
        try {
            // Load quarterly format data first (most recent and relevant)
            await this.loadFileList('quarterly');
            // Load employer format data second (historical)
            await this.loadFileList('employer');
        } catch (error) {
            console.error('Error loading data:', error);
            this.showError('Failed to load data. Please try again later.');
        }
    }

    async loadFileList(type) {
        const fileListElement = document.getElementById(`${type}-files`);
        let endpointUrl;
        
        if (type === 'employer') {
            endpointUrl = 'outputs/employer_format_endpoints.json';
        } else if (type === 'quarterly') {
            endpointUrl = 'outputs/quarterly_format_endpoints.json';
        } else {
            console.error(`Unknown type: ${type}`);
            return;
        }

        try {
            const response = await fetch(endpointUrl);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const data = await response.json();
            this.renderFileList(fileListElement, data.endpoints, type);
        } catch (error) {
            console.error(`Error loading ${type} files:`, error);
            fileListElement.innerHTML = `
                <div class="error">
                    <p>Failed to load ${type} format data.</p>
                    <p>Error: ${error.message}</p>
                </div>
            `;
        }
    }

    renderFileList(container, files, type) {
        if (!files || files.length === 0) {
            container.innerHTML = '<div class="no-data">No data available</div>';
            return;
        }

        // Sort files by date (most recent first)
        const sortedFiles = files.sort((a, b) => {
            const dateA = this.extractDateFromFilename(a.name);
            const dateB = this.extractDateFromFilename(b.name);
            
            if (!dateA && !dateB) return 0;
            if (!dateA) return 1;
            if (!dateB) return -1;
            
            return new Date(dateB) - new Date(dateA); // Most recent first
        });

        const fileListHTML = sortedFiles.map(file => {
            const date = this.extractDateFromFilename(file.name);
            const formattedDate = date ? new Date(date).toLocaleDateString('en-CA') : 'Unknown';
            
            return `
                <div class="file-item">
                    <div class="file-info">
                        <h4>${this.formatFilename(file.name)}</h4>
                        <p>Published: ${formattedDate}</p>
                    </div>
                    <div class="file-actions">
                        <a href="${file.url}" target="_blank" class="download-btn">Download CSV</a>
                    </div>
                </div>
            `;
        }).join('');

        container.innerHTML = fileListHTML;
    }

    formatFilename(filename) {
        // Convert filename to readable format
        return filename
            .replace(/_/g, ' ')
            .replace(/\b\w/g, l => l.toUpperCase())
            .replace(/\b(tfwp|pos|neg|q\d+)\b/gi, (match) => {
                const replacements = {
                    'tfwp': 'TFWP',
                    'pos': 'Positive',
                    'neg': 'Negative',
                    'q1': 'Q1',
                    'q2': 'Q2',
                    'q3': 'Q3',
                    'q4': 'Q4'
                };
                return replacements[match.toLowerCase()] || match;
            });
    }

    extractDateFromFilename(filename) {
        // Extract date from filename (format: YYYY-MM-DD_filename)
        const dateMatch = filename.match(/^(\d{4}-\d{2}-\d{2})/);
        return dateMatch ? dateMatch[1] : null;
    }

    async updateStats() {
        try {
            // Load both endpoint files to get counts
            const [employerResponse, quarterlyResponse] = await Promise.all([
                fetch('outputs/employer_format_endpoints.json'),
                fetch('outputs/quarterly_format_endpoints.json')
            ]);

            if (employerResponse.ok && quarterlyResponse.ok) {
                const employerData = await employerResponse.json();
                const quarterlyData = await quarterlyResponse.json();

                // Update basic counts
                document.getElementById('employer-count').textContent = employerData.endpoints?.length || 0;
                document.getElementById('quarterly-count').textContent = quarterlyData.endpoints?.length || 0;

                // Find latest update
                const allFiles = [
                    ...(employerData.endpoints || []),
                    ...(quarterlyData.endpoints || [])
                ];

                if (allFiles.length > 0) {
                    const latestFile = allFiles.reduce((latest, current) => {
                        const currentDate = this.extractDateFromFilename(current.name);
                        const latestDate = this.extractDateFromFilename(latest.name);
                        
                        if (!currentDate) return latest;
                        if (!latestDate) return current;
                        
                        return currentDate > latestDate ? current : latest;
                    });

                    const latestDate = this.extractDateFromFilename(latestFile.name);
                    if (latestDate) {
                        document.getElementById('latest-update').textContent = 
                            new Date(latestDate).toLocaleDateString('en-CA');
                    }

                    // Update comprehensive statistics
                    this.updateComprehensiveStats(allFiles);
                }
            }
        } catch (error) {
            console.error('Error updating stats:', error);
        }
    }

    updateComprehensiveStats(allFiles) {
        const statsSection = document.getElementById('comprehensive-stats');
        if (!statsSection) return;

        // Calculate date range
        const dates = allFiles
            .map(file => this.extractDateFromFilename(file.name))
            .filter(date => date !== null)
            .sort();

        if (dates.length > 0) {
            const earliestDate = new Date(dates[0]);
            const latestDate = new Date(dates[dates.length - 1]);

            const formatDate = (date) => {
                return date.toLocaleDateString('en-CA', { 
                    year: 'numeric', 
                    month: 'long' 
                });
            };

            // Estimate total records (assuming each file has multiple records)
            // This is a rough estimate - in reality, you'd need to parse the CSV files
            const estimatedRecordsPerFile = 100; // Conservative estimate
            const totalEstimatedRecords = allFiles.length * estimatedRecordsPerFile;

            statsSection.innerHTML = `
                <div class="stats-detail">
                    <div class="stat-item">
                        <span class="stat-label">Data Coverage:</span>
                        <span class="stat-value">${formatDate(earliestDate)} to ${formatDate(latestDate)}</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Total Files:</span>
                        <span class="stat-value">${allFiles.length}</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Estimated Records:</span>
                        <span class="stat-value">${totalEstimatedRecords.toLocaleString()}</span>
                    </div>
                </div>
            `;
        }
    }

    async updateCacheStats() {
        try {
            const response = await fetch('outputs/cache_statistics.json');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const data = await response.json();
            const cacheStats = data.cache_statistics;
            
            // Update main cache stat card
            const cachePostalCodesElement = document.getElementById('cache-postal-codes');
            if (cachePostalCodesElement) {
                cachePostalCodesElement.textContent = cacheStats.total_postal_codes || 0;
            }
            
            // Update detailed cache statistics section
            const cacheStatsSection = document.getElementById('cache-stats');
            if (cacheStatsSection && cacheStats.cache_file_exists) {
                const lastUpdated = new Date(cacheStats.last_updated);
                const formattedDate = lastUpdated.toLocaleDateString('en-CA', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });

                cacheStatsSection.innerHTML = `
                    <div class="stats-detail">
                        <div class="stat-item">
                            <span class="stat-label">Unique Postal Codes:</span>
                            <span class="stat-value">${cacheStats.total_postal_codes.toLocaleString()}</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-label">Unique Employers:</span>
                            <span class="stat-value">${cacheStats.unique_employers.toLocaleString()}</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-label">Unique Addresses:</span>
                            <span class="stat-value">${cacheStats.unique_addresses.toLocaleString()}</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-label">Cache File Size:</span>
                            <span class="stat-value">${cacheStats.file_size}</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-label">Last Updated:</span>
                            <span class="stat-value">${formattedDate}</span>
                        </div>
                    </div>
                `;
            } else if (cacheStatsSection) {
                cacheStatsSection.innerHTML = `
                    <div class="no-data">
                        <p>Address cache not available or empty</p>
                        <p>Cache statistics will appear after postal code processing is completed.</p>
                    </div>
                `;
            }
        } catch (error) {
            console.error('Error loading cache statistics:', error);
            
            // Show error in cache stats section
            const cacheStatsSection = document.getElementById('cache-stats');
            if (cacheStatsSection) {
                cacheStatsSection.innerHTML = `
                    <div class="error">
                        <p>Failed to load cache statistics.</p>
                        <p>Error: ${error.message}</p>
                    </div>
                `;
            }
            
            // Set cache card to 0 on error
            const cachePostalCodesElement = document.getElementById('cache-postal-codes');
            if (cachePostalCodesElement) {
                cachePostalCodesElement.textContent = '0';
            }
        }
    }

    async updateLastRunInfo() {
        try {
            // Fetch the latest workflow run information
            const response = await fetch('https://api.github.com/repos/relishcolouredhat/lmia-collector/actions/workflows/daily-pipeline.yml/runs?per_page=1&status=completed');
            
            if (response.ok) {
                const data = await response.json();
                
                if (data.workflow_runs && data.workflow_runs.length > 0) {
                    const latestRun = data.workflow_runs[0];
                    const updateTime = new Date(latestRun.updated_at);
                    const formattedTime = updateTime.toLocaleString('en-CA', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                    
                    // Update the timestamp display
                    const timeElement = document.getElementById('last-update-time');
                    if (timeElement) {
                        timeElement.textContent = formattedTime;
                    }
                    
                    // Update the GitHub Actions link to point to the specific run
                    const linkElement = document.getElementById('gh-action-link');
                    if (linkElement) {
                        linkElement.href = latestRun.html_url;
                        linkElement.textContent = `View Latest Run (${latestRun.conclusion || 'unknown'})`;
                    }
                }
            }
        } catch (error) {
            console.error('Error fetching last run info:', error);
            // Fallback to static link if API fails
            const timeElement = document.getElementById('last-update-time');
            if (timeElement) {
                timeElement.textContent = 'Unknown';
            }
        }
    }

    showError(message) {
        // Show error message to user
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-message';
        errorDiv.textContent = message;
        document.body.appendChild(errorDiv);
        
        // Remove after 5 seconds
        setTimeout(() => {
            errorDiv.remove();
        }, 5000);
    }
}

// Initialize the application when the page loads
document.addEventListener('DOMContentLoaded', () => {
    new LMIADataExplorer();
});
