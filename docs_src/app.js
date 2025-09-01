// LMIA Data Explorer Web Application
class LMIADataExplorer {
    constructor() {
        this.init();
    }

    init() {
        this.setupTabSwitching();
        this.loadData();
        this.updateStats();
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
            // Load positive reports
            await this.loadFileList('positive');
            // Load negative reports
            await this.loadFileList('negative');
        } catch (error) {
            console.error('Error loading data:', error);
            this.showError('Failed to load data. Please try again later.');
        }
    }

    async loadFileList(type) {
        const fileListElement = document.getElementById(`${type}-files`);
        const endpointUrl = `outputs/${type}_endpoints.json`;

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
                    <p>Failed to load ${type} reports.</p>
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

        const fileListHTML = files.map(file => {
            const date = this.extractDateFromFilename(file.name);
            const formattedDate = date ? new Date(date).toLocaleDateString('en-CA') : 'Unknown';
            
            return `
                <div class="file-item">
                    <div class="file-info">
                        <h4>${this.formatFilename(file.name)}</h4>
                        <p>Published: ${formattedDate}</p>
                    </div>
                    <div class="file-actions">
                        <a href="${file.url}" target="_blank" download>Download CSV</a>
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
            const [positiveResponse, negativeResponse] = await Promise.all([
                fetch('outputs/positive_endpoints.json'),
                fetch('outputs/negative_endpoints.json')
            ]);

            if (positiveResponse.ok && negativeResponse.ok) {
                const positiveData = await positiveResponse.json();
                const negativeData = await negativeResponse.json();

                // Update counts
                document.getElementById('positive-count').textContent = positiveData.endpoints?.length || 0;
                document.getElementById('negative-count').textContent = negativeData.endpoints?.length || 0;

                // Find latest update
                const allFiles = [
                    ...(positiveData.endpoints || []),
                    ...(negativeData.endpoints || [])
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
                }
            }
        } catch (error) {
            console.error('Error updating stats:', error);
        }
    }

    showError(message) {
        // Create and show error message
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error';
        errorDiv.innerHTML = `<p>${message}</p>`;
        
        // Add error styling
        errorDiv.style.cssText = `
            background: #fee;
            color: #c33;
            padding: 1rem;
            border-radius: 8px;
            border: 1px solid #fcc;
            text-align: center;
            margin: 1rem 0;
        `;
        
        document.querySelector('main').insertBefore(errorDiv, document.querySelector('main').firstChild);
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new LMIADataExplorer();
});

// Add some additional utility functions
window.addEventListener('load', () => {
    // Add loading animation
    const loadingElements = document.querySelectorAll('.loading');
    loadingElements.forEach(el => {
        el.style.opacity = '0.7';
        el.style.transition = 'opacity 0.3s ease';
    });
});
