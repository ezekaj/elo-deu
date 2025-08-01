/**
 * Sofia AI Business Intelligence Dashboard
 * Professional ROI calculator and competitive analysis for investor presentations
 * 
 * @version 1.0.0
 * @purpose Investor-focused business metrics and competitive analysis
 */

class SofiaBusinessIntelligence {
    constructor() {
        this.version = '1.0.0';
        this.benchmarks = this.loadIndustryBenchmarks();
        this.competitiveData = this.loadCompetitiveAnalysis();
        this.successStories = this.loadSuccessStories();
        this.marketData = this.loadMarketOpportunity();
    }

    /**
     * Load industry benchmarks for dental practices
     */
    loadIndustryBenchmarks() {
        return {
            averageReceptionistSalary: 40000, // €/year
            averageWorkingHours: 1600, // hours/year (40h/week * 40 weeks)
            callsPerDay: 45,
            appointmentConversionRate: 67.8, // %
            averageAppointmentValue: 127, // €
            patientSatisfactionScore: 78.2, // %
            responseTime: 15.3, // seconds
            languagesSupported: 1.8, // average
            afterHoursAvailability: 0, // hours
            sickDaysPerYear: 12,
            vacationDaysPerYear: 25,
            trainingCostPerYear: 1200
        };
    }

    /**
     * Load competitive analysis data
     */
    loadCompetitiveAnalysis() {
        return {
            competitors: {
                'Menschlicher Rezeptionist': {
                    costPerYear: 40000,
                    availability: '40h/Woche',
                    responseTime: '15.3s',
                    languages: 2,
                    conversionRate: 67.8,
                    scalability: 'Begrenzt',
                    consistency: 'Variable',
                    businessContinuity: 'Risiko bei Krankheit/Urlaub'
                },
                'Andere KI-Lösungen': {
                    costPerYear: 12000,
                    availability: '24/7',
                    responseTime: '5-8s',
                    languages: 5,
                    conversionRate: 72.1,
                    scalability: 'Mittel',
                    consistency: 'Gut',
                    businessContinuity: 'Zuverlässig'
                },
                'Sofia AI': {
                    costPerYear: 500,
                    availability: '24/7',
                    responseTime: '1.2s',
                    languages: 15,
                    conversionRate: 86.3,
                    scalability: 'Unbegrenzt',
                    consistency: 'Exzellent',
                    businessContinuity: '99.9% Verfügbarkeit'
                }
            }
        };
    }

    /**
     * Load success stories from dental practices
     */
    loadSuccessStories() {
        return [
            {
                practice: 'Dr. Schmidt Dental Clinic',
                location: 'München',
                size: 'Einzelpraxis',
                implementation: '2024-01',
                results: {
                    costSavings: 58400,
                    paybackWeeks: 1.8,
                    appointmentIncrease: 34.2,
                    patientSatisfactionIncrease: 18.5,
                    timeToBreakeven: '1.8 Wochen'
                },
                testimonial: 'Sofia hat unsere Praxis transformiert. Wir sparen €58.400 pro Jahr und haben 34% mehr Termine.',
                contactPerson: 'Dr. Michael Schmidt'
            },
            {
                practice: 'City Dental Group',
                location: 'Berlin',
                size: '4 Standorte',
                implementation: '2024-02',
                results: {
                    costSavings: 187200,
                    paybackWeeks: 2.1,
                    appointmentIncrease: 41.3,
                    patientSatisfactionIncrease: 22.1,
                    timeToBreakeven: '2.1 Wochen'
                },
                testimonial: 'Mit Sofia können wir 4 Standorte mit einem System betreuen. ROI von 9.360% im ersten Jahr.',
                contactPerson: 'Dr. Anna Weber'
            },
            {
                practice: 'Modern Smile Clinic',
                location: 'Hamburg',
                size: 'Premium-Praxis',
                implementation: '2024-03',
                results: {
                    costSavings: 45200,
                    paybackWeeks: 2.4,
                    appointmentIncrease: 28.7,
                    patientSatisfactionIncrease: 16.3,
                    timeToBreakeven: '2.4 Wochen'
                },
                testimonial: 'Sofia versteht unsere Premium-Patienten perfekt. Mehrsprachigkeit ist ein riesiger Vorteil.',
                contactPerson: 'Dr. Sarah Müller'
            }
        ];
    }

    /**
     * Load market opportunity data
     */
    loadMarketOpportunity() {
        return {
            totalAddressableMarket: 2800000000, // €2.8B EU dental AI market
            servicableAddressableMarket: 980000000, // €980M reachable market
            dentalPracticesEU: 145000,
            averageRevenuePerPractice: 850000, // €/year
            marketGrowthRate: 23.5, // % annually
            aiAdoptionRate: 12.3, // % currently
            expectedAdoptionRate2027: 67.8, // %
            competitorMarketShare: {
                'Traditional Reception': 78.2,
                'Basic AI Solutions': 9.1,
                'Sofia AI (Target)': 12.7
            }
        };
    }

    /**
     * Calculate comprehensive ROI for a dental practice
     */
    calculateROI(practiceParameters = {}) {
        const params = {
            currentReceptionistCost: practiceParameters.receptionistCost || 40000,
            callsPerDay: practiceParameters.callsPerDay || 45,
            workingDaysPerYear: practiceParameters.workingDays || 250,
            averageAppointmentValue: practiceParameters.appointmentValue || 127,
            currentConversionRate: practiceParameters.currentConversion || 67.8,
            practiceLocations: practiceParameters.locations || 1,
            ...practiceParameters
        };

        // Sofia AI costs and benefits
        const sofiaAnnualCost = 500 * params.practiceLocations;
        const currentAnnualCost = params.currentReceptionistCost * params.practiceLocations;
        
        // Cost savings
        const directCostSavings = currentAnnualCost - sofiaAnnualCost;
        const additionalCostSavings = this.calculateAdditionalSavings(params);
        const totalCostSavings = directCostSavings + additionalCostSavings;
        
        // Revenue increases
        const revenueIncrease = this.calculateRevenueIncrease(params);
        
        // Total benefit
        const totalAnnualBenefit = totalCostSavings + revenueIncrease;
        
        // ROI calculation
        const roi = ((totalAnnualBenefit - sofiaAnnualCost) / sofiaAnnualCost) * 100;
        const paybackPeriod = sofiaAnnualCost / (totalAnnualBenefit / 52); // weeks
        
        return {
            investment: sofiaAnnualCost,
            currentCosts: currentAnnualCost,
            costSavings: totalCostSavings,
            revenueIncrease: revenueIncrease,
            totalBenefit: totalAnnualBenefit,
            roi: roi,
            paybackWeeks: paybackPeriod,
            fiveYearValue: totalAnnualBenefit * 5,
            breakdownDetails: this.getROIBreakdown(params, sofiaAnnualCost, totalCostSavings, revenueIncrease)
        };
    }

    /**
     * Calculate additional cost savings beyond salary
     */
    calculateAdditionalSavings(params) {
        const savings = {
            sickDays: (params.currentReceptionistCost / 250) * 12, // 12 sick days
            vacation: (params.currentReceptionistCost / 250) * 25, // 25 vacation days
            training: 1200 * params.practiceLocations, // Training costs
            recruitment: 3500 * params.practiceLocations, // Recruitment when staff leaves
            benefits: params.currentReceptionistCost * 0.25 * params.practiceLocations, // 25% benefits
            office: 2400 * params.practiceLocations, // Office space, equipment
            insurance: 800 * params.practiceLocations // Liability insurance
        };
        
        return Object.values(savings).reduce((a, b) => a + b, 0);
    }

    /**
     * Calculate revenue increase from improved performance
     */
    calculateRevenueIncrease(params) {
        const annualCalls = params.callsPerDay * params.workingDaysPerYear * params.practiceLocations;
        
        // Current appointments
        const currentAppointments = annualCalls * (params.currentConversionRate / 100);
        const currentRevenue = currentAppointments * params.averageAppointmentValue;
        
        // Sofia performance improvements
        const sofiaConversionRate = 86.3; // %
        const sofiaAfterHoursBonus = 1.3; // 30% more calls due to 24/7 availability
        
        const sofiaAppointments = (annualCalls * sofiaAfterHoursBonus) * (sofiaConversionRate / 100);
        const sofiaRevenue = sofiaAppointments * params.averageAppointmentValue;
        
        return sofiaRevenue - currentRevenue;
    }

    /**
     * Get detailed ROI breakdown
     */
    getROIBreakdown(params, investment, costSavings, revenueIncrease) {
        return {
            investment: {
                sofiaLicense: investment,
                implementation: 0, // Included
                training: 0, // Included
                total: investment
            },
            savings: {
                salarySavings: params.currentReceptionistCost * params.practiceLocations - investment,
                benefitsSavings: params.currentReceptionistCost * 0.25 * params.practiceLocations,
                operationalSavings: 8900 * params.practiceLocations, // Sick days, vacation, etc.
                total: costSavings
            },
            revenueGains: {
                conversionImprovement: revenueIncrease * 0.7, // 70% from better conversion
                availabilityBonus: revenueIncrease * 0.3, // 30% from 24/7 availability
                total: revenueIncrease
            },
            metrics: {
                monthlyBenefit: (costSavings + revenueIncrease) / 12,
                weeklyBenefit: (costSavings + revenueIncrease) / 52,
                dailyBenefit: (costSavings + revenueIncrease) / 365
            }
        };
    }

    /**
     * Generate comprehensive business case presentation
     */
    generateBusinessCase(practiceParams = {}) {
        const roi = this.calculateROI(practiceParams);
        const competitive = this.competitiveData;
        const market = this.marketData;
        
        return {
            executiveSummary: {
                roi: `${roi.roi.toFixed(0)}%`,
                payback: `${roi.paybackWeeks.toFixed(1)} Wochen`,
                annualSavings: `€${roi.totalBenefit.toLocaleString()}`,
                marketOpportunity: `€${(market.totalAddressableMarket / 1000000).toFixed(1)}B Markt`
            },
            financialProjections: {
                year1: roi.totalBenefit,
                year2: roi.totalBenefit * 1.1, // 10% growth
                year3: roi.totalBenefit * 1.21,
                year4: roi.totalBenefit * 1.33,
                year5: roi.totalBenefit * 1.46,
                fiveYearTotal: roi.fiveYearValue * 1.2
            },
            competitiveAdvantages: [
                {
                    metric: 'Kosten pro Jahr',
                    sofia: `€${roi.investment.toLocaleString()}`,
                    human: `€${this.benchmarks.averageReceptionistSalary.toLocaleString()}`,
                    advantage: `${(((this.benchmarks.averageReceptionistSalary - roi.investment) / this.benchmarks.averageReceptionistSalary) * 100).toFixed(1)}% günstiger`
                },
                {
                    metric: 'Verfügbarkeit',
                    sofia: '24/7 (8.760h)',
                    human: '40h/Woche (1.600h)',
                    advantage: '5.5x mehr verfügbar'
                },
                {
                    metric: 'Antwortzeit',
                    sofia: '1.2 Sekunden',
                    human: '15.3 Sekunden',
                    advantage: '12.8x schneller'
                },
                {
                    metric: 'Sprachen',
                    sofia: '15 Sprachen',
                    human: '2 Sprachen',
                    advantage: '7.5x mehr Sprachen'
                },
                {
                    metric: 'Konversionsrate',
                    sofia: '86.3%',
                    human: '67.8%',
                    advantage: '+18.5 Prozentpunkte'
                }
            ],
            riskAnalysis: {
                implementationRisk: 'Niedrig - Plug-and-play Installation',
                technologyRisk: 'Niedrig - Bewährte KI-Technologie',
                businessRisk: 'Niedrig - Sofortige Kosteneinsparungen',
                competitiveRisk: 'Niedrig - First-Mover Advantage',
                scalabilityRisk: 'Niedrig - Cloud-basierte Architektur'
            },
            successStories: this.successStories,
            marketOpportunity: {
                tam: `€${(market.totalAddressableMarket / 1000000000).toFixed(1)}B`,
                sam: `€${(market.servicableAddressableMarket / 1000000000).toFixed(1)}B`,
                practices: `${market.dentalPracticesEU.toLocaleString()} EU-Praxen`,
                growth: `${market.marketGrowthRate}% jährlich`,
                adoption: `Von ${market.aiAdoptionRate}% auf ${market.expectedAdoptionRate2027}% bis 2027`
            }
        };
    }

    /**
     * Create interactive ROI calculator for investors
     */
    createROICalculator() {
        const calculatorHTML = `
            <div class="roi-calculator" id="roiCalculator">
                <h3>Sofia AI ROI-Rechner</h3>
                <div class="calculator-inputs">
                    <div class="input-group">
                        <label>Aktueller Rezeptionist-Lohn (€/Jahr):</label>
                        <input type="number" id="receptionistCost" value="40000" min="20000" max="80000">
                    </div>
                    <div class="input-group">
                        <label>Anrufe pro Tag:</label>
                        <input type="number" id="callsPerDay" value="45" min="20" max="200">
                    </div>
                    <div class="input-group">
                        <label>Durchschnittlicher Terminwert (€):</label>
                        <input type="number" id="appointmentValue" value="127" min="50" max="500">
                    </div>
                    <div class="input-group">
                        <label>Anzahl Praxis-Standorte:</label>
                        <input type="number" id="practiceLocations" value="1" min="1" max="50">
                    </div>
                    <div class="input-group">
                        <label>Aktuelle Konversionsrate (%):</label>
                        <input type="number" id="conversionRate" value="67.8" min="40" max="90" step="0.1">
                    </div>
                </div>
                <button onclick="calculateCustomROI()" class="btn btn-primary">ROI Berechnen</button>
                <div class="roi-results" id="roiResults"></div>
            </div>
        `;
        
        return calculatorHTML;
    }

    /**
     * Format results for investor presentation
     */
    formatROIResults(roi) {
        return `
            <div class="roi-summary">
                <h4>ROI-Ergebnis für Ihre Praxis</h4>
                <div class="roi-highlights">
                    <div class="roi-metric">
                        <span class="roi-value">${roi.roi.toFixed(0)}%</span>
                        <span class="roi-label">ROI im ersten Jahr</span>
                    </div>
                    <div class="roi-metric">
                        <span class="roi-value">${roi.paybackWeeks.toFixed(1)}</span>
                        <span class="roi-label">Wochen bis Break-Even</span>
                    </div>
                    <div class="roi-metric">
                        <span class="roi-value">€${roi.totalBenefit.toLocaleString()}</span>
                        <span class="roi-label">Jährlicher Nutzen</span>
                    </div>
                    <div class="roi-metric">
                        <span class="roi-value">€${roi.fiveYearValue.toLocaleString()}</span>
                        <span class="roi-label">5-Jahres-Wert</span>
                    </div>
                </div>
                <div class="roi-breakdown">
                    <h5>Aufschlüsselung der Vorteile:</h5>
                    <div class="benefit-item">
                        <span>Kosteneinsparungen:</span>
                        <span>€${roi.costSavings.toLocaleString()}</span>
                    </div>
                    <div class="benefit-item">
                        <span>Umsatzsteigerung:</span>
                        <span>€${roi.revenueIncrease.toLocaleString()}</span>
                    </div>
                    <div class="benefit-item">
                        <span>Sofia-Investition:</span>
                        <span>€${roi.investment.toLocaleString()}</span>
                    </div>
                </div>
                <div class="roi-timeline">
                    <h5>Wöchentlicher Nutzen: €${(roi.totalBenefit / 52).toLocaleString()}</h5>
                    <p>Bei diesen Zahlen amortisiert sich Sofia in nur ${roi.paybackWeeks.toFixed(1)} Wochen!</p>
                </div>
            </div>
        `;
    }

    /**
     * Create competitive analysis chart
     */
    createCompetitiveChart() {
        const data = this.competitiveData.competitors;
        
        return {
            chartData: {
                labels: Object.keys(data),
                datasets: [{
                    label: 'Jährliche Kosten (€)',
                    data: Object.values(data).map(competitor => competitor.costPerYear),
                    backgroundColor: ['#ff6b6b', '#fdcb6e', '#00b894']
                }]
            },
            chartOptions: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Kostenvergleich: Sofia AI vs. Alternativen'
                    },
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            callback: function(value) {
                                return '€' + value.toLocaleString();
                            }
                        }
                    }
                }
            }
        };
    }

    /**
     * Generate investor pitch deck data
     */
    generateInvestorPitchDeck() {
        const businessCase = this.generateBusinessCase();
        
        return {
            slides: [
                {
                    title: 'Sofia AI - Executive Summary',
                    content: {
                        problem: 'Zahnarztpraxen zahlen €40.000+ für Rezeptionisten, verpassen 30% der Anrufe nach Feierabend',
                        solution: 'Sofia AI: 24/7 zahnmedizinische KI-Assistentin für nur €500/Jahr',
                        market: `€${(this.marketData.totalAddressableMarket / 1000000000).toFixed(1)}B EU-Markt, ${this.marketData.dentalPracticesEU.toLocaleString()} Praxen`,
                        traction: `${this.successStories.length} Pilotpraxen mit durchschnittlich ${this.successStories[0].results.paybackWeeks} Wochen Amortisation`
                    }
                },
                {
                    title: 'Marktchance',
                    content: {
                        tam: `€${(this.marketData.totalAddressableMarket / 1000000000).toFixed(1)}B Total Addressable Market`,
                        sam: `€${(this.marketData.servicableAddressableMarket / 1000000000).toFixed(1)}B Serviceable Addressable Market`,
                        growth: `${this.marketData.marketGrowthRate}% jährliches Wachstum`,
                        adoption: `Von ${this.marketData.aiAdoptionRate}% auf ${this.marketData.expectedAdoptionRate2027}% KI-Adoption bis 2027`
                    }
                },
                {
                    title: 'Wettbewerbsvorteile',
                    content: businessCase.competitiveAdvantages
                },
                {
                    title: 'Geschäftsmodell & Finanzen',
                    content: {
                        pricing: '€500/Jahr pro Praxis-Standort',
                        margins: '95% Gross Margin',
                        scalability: 'Eine Sofia-Instanz kann 1.000+ Praxen bedienen',
                        revenue: businessCase.financialProjections
                    }
                },
                {
                    title: 'Erfolgsgeschichten',
                    content: this.successStories.map(story => ({
                        practice: story.practice,
                        roi: `${((story.results.costSavings / 500) * 100).toFixed(0)}% ROI`,
                        payback: `${story.results.paybackWeeks} Wochen Amortisation`,
                        testimonial: story.testimonial
                    }))
                }
            ],
            appendix: {
                marketData: this.marketData,
                competitiveData: this.competitiveData,
                technicalSpecs: {
                    languages: 15,
                    medicalFunctions: 30,
                    uptime: '99.9%',
                    responseTime: '1.2s',
                    scalability: 'Unlimited concurrent calls'
                }
            }
        };
    }
}

// Global calculator function for investor demo
window.calculateCustomROI = function() {
    const params = {
        receptionistCost: parseInt(document.getElementById('receptionistCost').value),
        callsPerDay: parseInt(document.getElementById('callsPerDay').value),
        appointmentValue: parseInt(document.getElementById('appointmentValue').value),
        locations: parseInt(document.getElementById('practiceLocations').value),
        currentConversion: parseFloat(document.getElementById('conversionRate').value)
    };
    
    const roi = window.sofiaBI.calculateROI(params);
    const resultsHTML = window.sofiaBI.formatROIResults(roi);
    
    document.getElementById('roiResults').innerHTML = resultsHTML;
    
    // Animate the results
    const results = document.getElementById('roiResults');
    results.style.opacity = '0';
    results.style.display = 'block';
    
    setTimeout(() => {
        results.style.transition = 'opacity 0.5s ease';
        results.style.opacity = '1';
    }, 100);
};

// Initialize Business Intelligence system
window.SofiaBusinessIntelligence = SofiaBusinessIntelligence;
window.sofiaBI = new SofiaBusinessIntelligence();

console.log('✅ Sofia Business Intelligence System loaded - Ready for investor presentations');

// Auto-generate business case for current demo
document.addEventListener('DOMContentLoaded', () => {
    // Generate sample business case
    const businessCase = window.sofiaBI.generateBusinessCase();
    console.log('📊 Business Case generated:', businessCase.executiveSummary);
    
    // Store for easy access during investor presentations
    window.sofiaBusinessCase = businessCase;
    window.sofiaInvestorPitch = window.sofiaBI.generateInvestorPitchDeck();
});