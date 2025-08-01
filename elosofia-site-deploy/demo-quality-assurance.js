/**
 * Sofia Investor Demo - Quality Assurance & Testing Suite
 * Comprehensive testing to ensure flawless investor presentations
 */

class DemoQualityAssurance {
    constructor() {
        this.testResults = {};
        this.criticalIssues = [];
        this.warnings = [];
        this.recommendations = [];
        
        // Run quality checks on load
        this.runAllChecks();
    }

    // CRITICAL FUNCTIONALITY TESTS
    async runAllChecks() {
        console.log('🔍 Starting comprehensive demo quality checks...');
        
        await this.testDemoFunctionality();
        await this.testPerformance();
        await this.testCompatibility();
        await this.testAccessibility();
        await this.testBusinessLogic();
        
        this.generateQualityReport();
    }

    async testDemoFunctionality() {
        const tests = [
            this.testModalOpen,
            this.testScenarioSwitching,
            this.testSofiaActivation,
            this.testMetricsUpdates,
            this.testErrorHandling,
            this.testKeyboardShortcuts
        ];

        this.testResults.functionality = {};
        
        for (const test of tests) {
            try {
                const result = await test.call(this);
                this.testResults.functionality[test.name] = { 
                    passed: true, 
                    result 
                };
            } catch (error) {
                this.testResults.functionality[test.name] = { 
                    passed: false, 
                    error: error.message 
                };
                this.criticalIssues.push(`${test.name}: ${error.message}`);
            }
        }
    }

    testModalOpen() {
        // Test demo modal opening
        const modal = document.getElementById('demoModal');
        if (!modal) throw new Error('Demo modal not found');
        
        // Simulate opening
        if (typeof startDemo === 'function') {
            startDemo();
            const isVisible = window.getComputedStyle(modal).display !== 'none';
            if (!isVisible) throw new Error('Modal failed to open');
            
            // Close it
            if (typeof closeDemo === 'function') closeDemo();
            return 'Modal opens and closes correctly';
        }
        throw new Error('startDemo function not found');
    }

    testScenarioSwitching() {
        // Test scenario button functionality
        const scenarioButtons = document.querySelectorAll('.scenario-btn');
        if (scenarioButtons.length < 4) {
            throw new Error('Missing scenario buttons');
        }
        
        // Test each scenario
        const scenarios = ['emergency', 'complex', 'afterhours', 'custom'];
        for (const scenario of scenarios) {
            const btn = document.querySelector(`[onclick="selectScenario('${scenario}')"]`);
            if (!btn) throw new Error(`Missing scenario button: ${scenario}`);
        }
        
        return `All ${scenarios.length} scenarios available`;
    }

    testSofiaActivation() {
        // Test Sofia activation button
        const sofiaBtn = document.getElementById('startSofiaBtn');
        if (!sofiaBtn) throw new Error('Sofia activation button not found');
        
        const status = document.getElementById('sofiaStatus');
        if (!status) throw new Error('Sofia status element not found');
        
        return 'Sofia activation elements present';
    }

    testMetricsUpdates() {
        // Test business metrics elements
        const metricElements = [
            'callsHandled',
            'appointmentsBooked', 
            'timeSaved',
            'costSavings'
        ];
        
        for (const metricId of metricElements) {
            const element = document.getElementById(metricId);
            if (!element) throw new Error(`Missing metric element: ${metricId}`);
        }
        
        return `All ${metricElements.length} metrics elements present`;
    }

    testErrorHandling() {
        // Test that error handlers are in place
        const hasGlobalErrorHandler = window.onerror !== null || 
            window.addEventListener.toString().includes('error');
        
        if (!hasGlobalErrorHandler) {
            this.warnings.push('No global error handler detected');
        }
        
        return 'Error handling mechanisms checked';
    }

    testKeyboardShortcuts() {
        // Test presenter shortcuts are available
        if (window.demoEnhancements && 
            typeof window.demoEnhancements.selectScenario === 'function') {
            return 'Keyboard shortcuts available';
        }
        
        this.warnings.push('Keyboard shortcuts not available');
        return 'Basic functionality only';
    }

    // PERFORMANCE TESTING
    async testPerformance() {
        this.testResults.performance = {};
        
        // Test load time
        const loadTime = performance.timing.loadEventEnd - 
                        performance.timing.navigationStart;
        
        this.testResults.performance.loadTime = {
            value: loadTime,
            passed: loadTime < 3000,
            benchmark: '< 3 seconds'
        };
        
        if (loadTime > 3000) {
            this.warnings.push(`Slow load time: ${loadTime}ms`);
        }
        
        // Test animation performance
        this.testAnimationPerformance();
        
        // Test memory usage
        if (performance.memory) {
            const memoryUsage = performance.memory.usedJSHeapSize / 1024 / 1024;
            this.testResults.performance.memory = {
                value: `${memoryUsage.toFixed(2)} MB`,
                passed: memoryUsage < 50,
                benchmark: '< 50 MB'
            };
            
            if (memoryUsage > 50) {
                this.warnings.push(`High memory usage: ${memoryUsage.toFixed(2)} MB`);
            }
        }
    }

    testAnimationPerformance() {
        // Check CSS animation performance
        const animatedElements = document.querySelectorAll('[class*="animate"], .hero-content, .sofia-avatar');
        let heavyAnimations = 0;
        
        animatedElements.forEach(el => {
            const styles = getComputedStyle(el);
            if (styles.animationDuration && 
                parseFloat(styles.animationDuration) > 3) {
                heavyAnimations++;
            }
        });
        
        this.testResults.performance.animations = {
            heavyAnimations,
            passed: heavyAnimations < 3,
            total: animatedElements.length
        };
    }

    // COMPATIBILITY TESTING
    async testCompatibility() {
        this.testResults.compatibility = {};
        
        // Browser detection
        const browser = this.detectBrowser();
        this.testResults.compatibility.browser = browser;
        
        // Feature support tests
        const features = {
            fetch: typeof fetch !== 'undefined',
            promises: typeof Promise !== 'undefined',
            grid: CSS.supports('display', 'grid'),
            flexbox: CSS.supports('display', 'flex'),
            customProperties: CSS.supports('--custom: value'),
            intersectionObserver: 'IntersectionObserver' in window,
            webGL: this.testWebGL()
        };
        
        this.testResults.compatibility.features = features;
        
        // Check for polyfills needed
        const needsPolyfills = [];
        if (!features.fetch) needsPolyfills.push('fetch');
        if (!features.promises) needsPolyfills.push('Promise');
        if (!features.intersectionObserver) needsPolyfills.push('IntersectionObserver');
        
        if (needsPolyfills.length > 0) {
            this.warnings.push(`Polyfills recommended: ${needsPolyfills.join(', ')}`);
        }
        
        // Mobile/tablet detection
        this.testResults.compatibility.device = {
            mobile: /Mobile|Android|iPhone|iPad/.test(navigator.userAgent),
            tablet: /iPad|Android.*Tablet/.test(navigator.userAgent),
            touch: 'ontouchstart' in window,
            screenSize: `${screen.width}x${screen.height}`
        };
    }

    detectBrowser() {
        const ua = navigator.userAgent;
        if (ua.includes('Chrome')) return { name: 'Chrome', supported: true };
        if (ua.includes('Firefox')) return { name: 'Firefox', supported: true };
        if (ua.includes('Safari')) return { name: 'Safari', supported: true };
        if (ua.includes('Edge')) return { name: 'Edge', supported: true };
        if (ua.includes('IE')) return { name: 'Internet Explorer', supported: false };
        return { name: 'Unknown', supported: false };
    }

    testWebGL() {
        try {
            const canvas = document.createElement('canvas');
            return !!(canvas.getContext('webgl') || canvas.getContext('experimental-webgl'));
        } catch (e) {
            return false;
        }
    }

    // ACCESSIBILITY TESTING
    async testAccessibility() {
        this.testResults.accessibility = {};
        
        // Test for alt texts on images
        const images = document.querySelectorAll('img');
        const imagesWithoutAlt = Array.from(images).filter(img => !img.alt);
        
        this.testResults.accessibility.images = {
            total: images.length,
            missingAlt: imagesWithoutAlt.length,
            passed: imagesWithoutAlt.length === 0
        };
        
        // Test for proper heading structure
        const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
        this.testResults.accessibility.headings = {
            count: headings.length,
            hasH1: document.querySelector('h1') !== null
        };
        
        // Test for ARIA labels on interactive elements
        const interactiveElements = document.querySelectorAll('button, a, input, select');
        const elementsWithoutLabels = Array.from(interactiveElements).filter(el => 
            !el.getAttribute('aria-label') && 
            !el.getAttribute('aria-labelledby') && 
            !el.textContent.trim()
        );
        
        this.testResults.accessibility.interactive = {
            total: interactiveElements.length,
            missingLabels: elementsWithoutLabels.length,
            passed: elementsWithoutLabels.length === 0
        };
        
        // Color contrast check (basic)
        this.testResults.accessibility.contrast = this.checkColorContrast();
    }

    checkColorContrast() {
        // Basic color contrast check for common elements
        const elements = document.querySelectorAll('.btn, .hero, .modal-header');
        let contrastIssues = 0;
        
        elements.forEach(el => {
            const styles = getComputedStyle(el);
            const bgColor = styles.backgroundColor;
            const textColor = styles.color;
            
            // Simplified contrast check (full implementation would be more complex)
            if (bgColor === textColor) {
                contrastIssues++;
            }
        });
        
        return {
            elementsChecked: elements.length,
            issues: contrastIssues,
            passed: contrastIssues === 0
        };
    }

    // BUSINESS LOGIC TESTING
    async testBusinessLogic() {
        this.testResults.businessLogic = {};
        
        // Test ROI calculations
        if (window.sofiaDemo && typeof window.sofiaDemo.calculateROI === 'function') {
            try {
                const roi = window.sofiaDemo.calculateROI();
                this.testResults.businessLogic.roi = {
                    calculated: true,
                    values: roi,
                    realistic: roi.roi > 1000 && roi.roi < 10000
                };
            } catch (error) {
                this.testResults.businessLogic.roi = {
                    calculated: false,
                    error: error.message
                };
            }
        }
        
        // Test metrics animation
        const metricsInterval = setInterval(() => {
            const callsEl = document.getElementById('callsHandled');
            if (callsEl) {
                const initialValue = parseInt(callsEl.textContent);
                
                setTimeout(() => {
                    const newValue = parseInt(callsEl.textContent);
                    this.testResults.businessLogic.metricsAnimation = {
                        working: newValue !== initialValue,
                        initialValue,
                        newValue
                    };
                    clearInterval(metricsInterval);
                }, 5000);
            }
        }, 1000);
    }

    // QUALITY REPORT GENERATION
    generateQualityReport() {
        const report = {
            timestamp: new Date().toISOString(),
            overallScore: this.calculateOverallScore(),
            criticalIssues: this.criticalIssues,
            warnings: this.warnings,
            recommendations: this.generateRecommendations(),
            testResults: this.testResults,
            readinessLevel: this.assessReadiness()
        };
        
        console.log('📊 Demo Quality Report:', report);
        this.displayQualityStatus(report);
        
        return report;
    }

    calculateOverallScore() {
        let totalTests = 0;
        let passedTests = 0;
        
        Object.values(this.testResults).forEach(category => {
            Object.values(category).forEach(test => {
                totalTests++;
                if (test.passed) passedTests++;
            });
        });
        
        return totalTests > 0 ? Math.round((passedTests / totalTests) * 100) : 0;
    }

    generateRecommendations() {
        const recommendations = [];
        
        if (this.criticalIssues.length > 0) {
            recommendations.push('🚨 Fix critical issues before investor presentation');
        }
        
        if (this.warnings.includes('Slow load time')) {
            recommendations.push('⚡ Optimize images and reduce bundle size');
        }
        
        if (this.testResults.compatibility?.browser?.name === 'Internet Explorer') {
            recommendations.push('🌐 Add IE compatibility notice or redirect');
        }
        
        if (this.testResults.accessibility?.images?.missingAlt > 0) {
            recommendations.push('♿ Add alt text to images for accessibility');
        }
        
        return recommendations;
    }

    assessReadiness() {
        if (this.criticalIssues.length > 0) return 'NOT_READY';
        if (this.warnings.length > 3) return 'NEEDS_ATTENTION';
        if (this.calculateOverallScore() < 80) return 'FAIR';
        if (this.calculateOverallScore() < 95) return 'GOOD';
        return 'EXCELLENT';
    }

    displayQualityStatus(report) {
        // Create quality indicator in the UI
        const indicator = document.createElement('div');
        indicator.id = 'quality-indicator';
        indicator.style.cssText = `
            position: fixed;
            top: 10px;
            right: 10px;
            background: ${this.getStatusColor(report.readinessLevel)};
            color: white;
            padding: 8px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            z-index: 10000;
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
            cursor: pointer;
        `;
        
        indicator.textContent = `Demo Quality: ${report.overallScore}% (${report.readinessLevel})`;
        indicator.title = 'Click for detailed quality report';
        indicator.onclick = () => this.showDetailedReport(report);
        
        document.body.appendChild(indicator);
        
        // Auto-hide after 10 seconds
        setTimeout(() => {
            if (indicator.parentNode) {
                indicator.style.opacity = '0.3';
            }
        }, 10000);
    }

    getStatusColor(readinessLevel) {
        const colors = {
            'EXCELLENT': '#00b894',
            'GOOD': '#00cec9', 
            'FAIR': '#fdcb6e',
            'NEEDS_ATTENTION': '#e17055',
            'NOT_READY': '#d63031'
        };
        return colors[readinessLevel] || '#74b9ff';
    }

    showDetailedReport(report) {
        const reportWindow = window.open('', '_blank', 'width=800,height=600');
        reportWindow.document.write(`
            <html>
            <head>
                <title>Sofia Demo Quality Report</title>
                <style>
                    body { font-family: 'Inter', sans-serif; margin: 20px; }
                    .header { background: #667eea; color: white; padding: 20px; border-radius: 10px; }
                    .section { margin: 20px 0; padding: 15px; border-left: 4px solid #00b894; }
                    .critical { color: #d63031; font-weight: bold; }
                    .warning { color: #e17055; }
                    .good { color: #00b894; }
                    pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow: auto; }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>📊 Sofia Demo Quality Report</h1>
                    <p>Generated: ${report.timestamp}</p>
                    <p>Overall Score: <strong>${report.overallScore}%</strong></p>
                    <p>Readiness Level: <strong>${report.readinessLevel}</strong></p>
                </div>
                
                ${report.criticalIssues.length > 0 ? `
                <div class="section">
                    <h2 class="critical">🚨 Critical Issues</h2>
                    <ul>
                        ${report.criticalIssues.map(issue => `<li class="critical">${issue}</li>`).join('')}
                    </ul>
                </div>
                ` : ''}
                
                ${report.warnings.length > 0 ? `
                <div class="section">
                    <h2 class="warning">⚠️ Warnings</h2>
                    <ul>
                        ${report.warnings.map(warning => `<li class="warning">${warning}</li>`).join('')}
                    </ul>
                </div>
                ` : ''}
                
                <div class="section">
                    <h2 class="good">💡 Recommendations</h2>
                    <ul>
                        ${report.recommendations.map(rec => `<li>${rec}</li>`).join('')}
                    </ul>
                </div>
                
                <div class="section">
                    <h2>🔍 Detailed Test Results</h2>
                    <pre>${JSON.stringify(report.testResults, null, 2)}</pre>
                </div>
            </body>
            </html>
        `);
    }

    // PUBLIC API
    getQualityScore() {
        return this.calculateOverallScore();
    }

    getCriticalIssues() {
        return this.criticalIssues;
    }

    isReadyForInvestors() {
        return this.criticalIssues.length === 0 && this.calculateOverallScore() >= 90;
    }
}

// Initialize quality assurance
document.addEventListener('DOMContentLoaded', () => {
    // Wait a bit for other scripts to load
    setTimeout(() => {
        window.demoQA = new DemoQualityAssurance();
    }, 2000);
});

// Export for external use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = DemoQualityAssurance;
}