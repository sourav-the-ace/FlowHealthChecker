import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import initiateAsyncScan from '@salesforce/apex/FlowScannerService.initiateAsyncScan';
import getScanStatus     from '@salesforce/apex/FlowScannerService.getScanStatus';
import getScanResults    from '@salesforce/apex/FlowHealthCheckerController.getScanResults';
import getRules          from '@salesforce/apex/FlowHealthCheckerController.getRules';
import getScanHistory    from '@salesforce/apex/FlowHealthCheckerController.getScanHistory';

const POLL_INTERVAL_MS = 3000;
const POLL_MESSAGES    = [
    'Connecting to Tooling API…',
    'Fetching active flows…',
    'Analysing flow metadata…',
    'Running rule checks…',
    'Checking for fault paths…',
    'Scanning for DML in loops…',
    'Detecting hardcoded values…',
    'Checking variable usage…',
    'Mapping flow connectors…',
    'Calculating health score…',
    'Finalising results…'
];

export default class FlowHealthChecker extends NavigationMixin(LightningElement) {

    @track isScanning        = false;
    @track hasScanResult     = false;
    @track hasViolations     = false;
    @track errorMessage      = null;
    @track progressMessage   = '';
    @track progressStep      = 0;
    @track scanSummary       = {
        totalFlows: '—', errors: '—', warnings: '—',
        score: '—', affectedFlows: '—'
    };
    @track allResults        = [];
    @track activeFilter      = 'All';
    @track searchQuery       = '';
    @track filteredFlowGroups = [];
    @track metaText          = '';
    @track showRulesModal    = false;
    @track rulesList         = [];
    @track activeRuleCount   = 0;
    @track showHistoryModal  = false;
    @track historyList       = [];

    expandedFlows  = new Set();
    pollTimer      = null;
    currentScanId  = null;
    progressTimer  = null;
    progressIndex  = 0;

    // ── Scan ─────────────────────────────────────────────────────

    async handleScan() {
        this.isScanning     = true;
        this.errorMessage   = null;
        this.hasScanResult  = false;
        this.progressIndex  = 0;
        this.progressMessage = POLL_MESSAGES[0];

        try {
            // Kick off async scan — returns immediately with scanId
            this.currentScanId = await initiateAsyncScan();

            // Start progress message cycling
            this.startProgressCycle();

            // Start polling for completion
            this.startPolling();

        } catch (err) {
            this.isScanning   = false;
            this.errorMessage = err.body?.message || err.message || 'Unknown error.';
            this.stopProgressCycle();
        }
    }

    startProgressCycle() {
        this.progressTimer = setInterval(() => {
            this.progressIndex = (this.progressIndex + 1) % POLL_MESSAGES.length;
            this.progressMessage = POLL_MESSAGES[this.progressIndex];
        }, 2000);
    }

    stopProgressCycle() {
        if (this.progressTimer) {
            clearInterval(this.progressTimer);
            this.progressTimer = null;
        }
    }

    startPolling() {
        this.pollTimer = setInterval(async () => {
            try {
                const status = await getScanStatus({
                    scanId: this.currentScanId
                });

                if (status.status === 'Complete') {
                    this.stopPolling();
                    this.stopProgressCycle();
                    const data = await getScanResults({
                        scanId: this.currentScanId
                    });
                    this.processScanData(data, this.currentScanId);
                    this.isScanning = false;

                } else if (status.status === 'Failed') {
                    this.stopPolling();
                    this.stopProgressCycle();
                    this.isScanning   = false;
                    this.errorMessage = 'Scan failed: ' + (status.errorMessage || 'Unknown error');
                }
                // Pending / Running — keep polling

            } catch (err) {
                this.stopPolling();
                this.stopProgressCycle();
                this.isScanning   = false;
                this.errorMessage = err.body?.message || err.message || 'Polling error.';
            }
        }, POLL_INTERVAL_MS);
    }

    stopPolling() {
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
            this.pollTimer = null;
        }
    }

    disconnectedCallback() {
        this.stopPolling();
        this.stopProgressCycle();
    }

    // ── Data processing ──────────────────────────────────────────

    processScanData(data, scanId) {
        const scan    = data.scan;
        const results = data.results;

        const errors   = results.filter(r => r.svfhc__Severity__c === 'Error').length;
        const warnings = results.filter(r => r.svfhc__Severity__c === 'Warning').length;
        const total    = scan.svfhc__Total_Flows_Scanned__c || 0;
        const affected = new Set(results.map(r => r.svfhc__Flow_API_Name__c)).size;

        const score = this.computeHealthScore(total, errors, warnings) + '%';

        this.scanSummary = {
            scanId,
            totalFlows   : total,
            errors,
            warnings,
            score,
            affectedFlows: affected,
            scanDate     : new Date(scan.svfhc__Scan_Date__c).toLocaleString()
        };

        this.allResults = results.map(r => ({
            ...r,
            rowClass    : this.rowClass(r.svfhc__Severity__c),
            badgeClass  : this.badgeClass(r.svfhc__Severity__c),
            severityIcon: this.severityIcon(r.svfhc__Severity__c)
        }));

        new Set(results.map(r => r.svfhc__Flow_API_Name__c))
            .forEach(f => this.expandedFlows.add(f));

        this.hasScanResult = true;
        this.activeFilter  = 'All';
        this.searchQuery   = '';
        this.rebuildGroups();
    }

    rebuildGroups() {
        let data = this.activeFilter === 'All'
            ? [...this.allResults]
            : this.allResults.filter(r => r.svfhc__Severity__c === this.activeFilter);

        if (this.searchQuery) {
            const q = this.searchQuery.toLowerCase();
            data = data.filter(r =>
                r.svfhc__Flow_API_Name__c.toLowerCase().includes(q)
            );
        }

        const map = new Map();
        data.forEach(r => {
            const k = r.svfhc__Flow_API_Name__c;
            if (!map.has(k)) map.set(k, []);
            map.get(k).push(r);
        });

        const groups = [];
        map.forEach((violations, flowApiName) => {
            const errs     = violations.filter(
                v => v.svfhc__Severity__c === 'Error').length;
            const warns    = violations.filter(
                v => v.svfhc__Severity__c === 'Warning').length;
            const expanded = this.expandedFlows.has(flowApiName);
            const flowDefinitionId =
                violations[0]?.svfhc__Flow_Definition_Id__c || null;

            groups.push({
                flowApiName,
                violations,
                errorCount      : errs  || null,
                warningCount    : warns || null,
                isExpanded      : expanded,
                chevron         : expanded ? '▼' : '▶',
                flowDefinitionId,
                violationsId    : 'violations-' + flowApiName.replace(/[^a-zA-Z0-9]/g, '-'),
                healthChipClass : errs  > 0
                    ? 'fhc-health-chip fhc-chip-critical'
                    : warns > 0
                    ? 'fhc-health-chip fhc-chip-warn'
                    : 'fhc-health-chip fhc-chip-ok',
                healthLabel     : errs  > 0 ? 'Critical'
                                : warns > 0 ? 'Needs Review'
                                :             'Healthy'
            });
        });

        groups.sort((a, b) => {
            const ae = a.violations.filter(
                v => v.svfhc__Severity__c === 'Error').length;
            const be = b.violations.filter(
                v => v.svfhc__Severity__c === 'Error').length;
            return be - ae;
        });

        this.filteredFlowGroups = groups;
        this.hasViolations      = groups.length > 0;

        const totalV = data.length;
        const totalF = groups.length;
        this.metaText = this.hasScanResult
            ? `Showing ${totalV} violation${totalV !== 1 ? 's' : ''} across ${totalF} flow${totalF !== 1 ? 's' : ''}`
            : '';
    }

    // ── Toggle ───────────────────────────────────────────────────

    handleToggle(event) {
        const flow = event.currentTarget.dataset.flow;
        if (this.expandedFlows.has(flow)) {
            this.expandedFlows.delete(flow);
        } else {
            this.expandedFlows.add(flow);
        }
        this.rebuildGroups();
    }

    expandAll() {
        this.allResults.forEach(r =>
            this.expandedFlows.add(r.svfhc__Flow_API_Name__c)
        );
        this.rebuildGroups();
    }

    collapseAll() {
        this.expandedFlows.clear();
        this.rebuildGroups();
    }

    // ── Search & Filter ──────────────────────────────────────────

    handleSearch(event) {
        this.searchQuery = event.target.value;
        this.rebuildGroups();
    }

    filterAll()     { this.activeFilter = 'All';     this.rebuildGroups(); }
    filterError()   { this.activeFilter = 'Error';   this.rebuildGroups(); }
    filterWarning() { this.activeFilter = 'Warning'; this.rebuildGroups(); }
    filterInfo()    { this.activeFilter = 'Info';    this.rebuildGroups(); }

    // ── Open Flow ────────────────────────────────────────────────

    handleOpenFlow(event) {
        const definitionId = event.currentTarget.dataset.id;
        if (!definitionId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/builder_platform_interaction/flowBuilder.app?flowDefId='
                     + definitionId
            }
        });
    }

    // ── Rules Modal ──────────────────────────────────────────────

    async openRulesModal() {
        if (this.rulesList.length === 0) {
            try {
                const rules = await getRules();
                this.rulesList = rules.map(r => ({
                    label       : r.MasterLabel,
                    severity    : r.svfhc__Severity__c,
                    description : r.svfhc__Description__c,
                    phase       : this.getRulePhase(r.MasterLabel),
                    badgeClass  : this.badgeClass(r.svfhc__Severity__c),
                    severityIcon: this.severityIcon(r.svfhc__Severity__c)
                }));
                this.activeRuleCount = rules.filter(r => r.svfhc__Active__c).length;
            } catch (err) {
                this.errorMessage =
                    'Could not load rules: ' + (err.body?.message || err.message);
                return;
            }
        }
        this.showRulesModal = true;
    }

    closeRulesModal()  { this.showRulesModal = false; }
    stopPropagation(e) { e.stopPropagation(); }

    getRulePhase(label) {
        const phase1 = [
            'No Fault Path', 'DML In Loop', 'Missing Description',
            'Too Many Elements', 'Hardcoded Id'
        ];
        return phase1.includes(label) ? 'Phase 1' : 'Phase 2';
    }

    // ── Scan History ─────────────────────────────────────────────

    async openHistoryModal() {
        try {
            const history = await getScanHistory({ maxRecords: 20 });
            this.historyList = history
                .slice()
                .reverse() // oldest → newest, so the chart reads left-to-right
                .map(s => {
                    const score = this.computeHealthScore(
                        s.svfhc__Total_Flows_Scanned__c,
                        s.svfhc__Errors__c,
                        s.svfhc__Warnings__c
                    );
                    return {
                        id: s.Id,
                        date: new Date(s.svfhc__Scan_Date__c).toLocaleDateString(),
                        totalFlows: s.svfhc__Total_Flows_Scanned__c,
                        errors: s.svfhc__Errors__c || 0,
                        warnings: s.svfhc__Warnings__c || 0,
                        score,
                        barStyle: `height:${score}%`,
                        barClass: score >= 80
                            ? 'fhc-bar fhc-bar-good'
                            : score >= 50
                            ? 'fhc-bar fhc-bar-warn'
                            : 'fhc-bar fhc-bar-bad'
                    };
                });
        } catch (err) {
            this.errorMessage =
                'Could not load scan history: ' + (err.body?.message || err.message);
            return;
        }
        this.showHistoryModal = true;
    }

    closeHistoryModal() { this.showHistoryModal = false; }

    // Shared by processScanData (live scan) and openHistoryModal (history)
    // so both views always compute the score the same way.
    computeHealthScore(total, errors, warnings) {
        // Point-based: each Error costs more than each Warning, and the
        // penalty scales with org size so a 1-flow org and a 200-flow org
        // aren't judged on the same absolute scale.
        const totalFlowsNum = Number(total) || 1;
        const errPoints     = Math.min((Number(errors)   || 0) * (100 / totalFlowsNum) * 0.6, 100);
        const warnPoints    = Math.min((Number(warnings) || 0) * (100 / totalFlowsNum) * 0.2, 100);
        return Math.max(0, Math.round(100 - errPoints - warnPoints));
    }

    // ── Helpers ──────────────────────────────────────────────────

    rowClass(s)     {
        return s==='Error'   ? 'fhc-row-err'
             : s==='Warning' ? 'fhc-row-warn'
             :                 'fhc-row-info';
    }
    badgeClass(s)   {
        return s==='Error'   ? 'fhc-badge fhc-badge-err'
             : s==='Warning' ? 'fhc-badge fhc-badge-warn'
             :                 'fhc-badge fhc-badge-info';
    }
    severityIcon(s) {
        return s==='Error' ? '🔴' : s==='Warning' ? '🟡' : '🔵';
    }

    get filterAllClass()     {
        return this.activeFilter==='All'     ? 'fhc-filter-btn active' : 'fhc-filter-btn';
    }
    get filterErrorClass()   {
        return this.activeFilter==='Error'   ? 'fhc-filter-btn active' : 'fhc-filter-btn';
    }
    get filterWarningClass() {
        return this.activeFilter==='Warning' ? 'fhc-filter-btn active' : 'fhc-filter-btn';
    }
    get filterInfoClass()    {
        return this.activeFilter==='Info'    ? 'fhc-filter-btn active' : 'fhc-filter-btn';
    }
    // ── ARIA getters ─────────────────────────────────────────────

    get scanButtonLabel() {
        return this.isScanning ? 'Scan in progress, please wait' : 'Run scan now';
    }

    get isFilterAll()     { return this.activeFilter === 'All'; }
    get isFilterError()   { return this.activeFilter === 'Error'; }
    get isFilterWarning() { return this.activeFilter === 'Warning'; }
    get isFilterInfo()    { return this.activeFilter === 'Info'; }

    // ── Keyboard navigation for flow headers ─────────────────────

    handleToggleKeydown(event) {
        // Allow Enter and Space to toggle flow groups
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleToggle(event);
        }
    }
}