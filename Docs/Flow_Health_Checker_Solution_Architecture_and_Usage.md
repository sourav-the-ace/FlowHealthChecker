# Flow Health Checker — Solution Architecture, Security & Usage Guide

> **Package Name**: Flow Health Checker  
> **Namespace**: `svfhc`  
> **Package Type**: Second-Generation Managed Package (2GP)  
> **Target API Version**: `61.0` (Summer '24)  
> **Documentation Type**: AppExchange Architecture & Security Review Submission Asset

---

## 1. Executive Summary & Solution Overview

**Flow Health Checker** is a 100% native Salesforce Second-Generation Managed Package (2GP) designed to audit, analyze, and score an enterprise organization's active Flows against Salesforce architectural best practices, governor limit hazards, and user experience anti-patterns.

### Core Architectural Guarantees

- **100% Native Platform Architecture**: Runs entirely within the subscriber's Salesforce instance.
- **Zero External Data Egress**: Zero callouts to external servers, third-party clouds, or remote analytics endpoints.
- **In-Org Metadata Introspection**: Connects internally to the Salesforce Tooling API via encrypted loopback HTTPS callouts to inspect active Flow metadata.
- **Governor Limit Protection**: Asynchronous chained Queueable batches (20 flows per batch) ensure fresh limits per transaction.

---

## 2. System & Solution Architecture

The solution uses a modern multi-tier architecture with clear boundaries between UI, service coordination, metadata retrieval, rule evaluation, and data storage:

| Layer                           | Components                                                       | Security & Functional Role                                                                                                                          |
| ------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Presentation Layer**          | `flowHealthChecker` (LWC), Custom App & Tab                      | Renders interactive dashboard, initiates scans via AuraEnabled actions, polls status, and displays grouped violations and health scores.            |
| **Controller & Service Layer**  | `FlowHealthCheckerController.cls`, `FlowScannerService.cls`      | Enforces CRUD/FLS pre-flight checks, coordinates session ID acquisition, executes asynchronous worker jobs, and calculates weighted health scores.  |
| **Metadata Ingestion Layer**    | `FlowMetadataService.cls`, `SessionHelper.page`                  | Retrieves API-enabled session tokens, executes HTTPS loopback Tooling API queries, and parses raw Flow JSON into typed `FlowWrapper` object models. |
| **Rules Engine Layer**          | `IFlowRule.cls`, 12 Rule Evaluation Classes, `Flow_Rule__mdt`    | Evaluates flows in-memory against 12 best-practice rules (DML in loops, hardcoded IDs/URLs, missing descriptions, fault path handling, etc.).       |
| **Asynchronous Execution**      | `FlowScanQueueable.cls`, `FlowScanBatchQueueable.cls`            | Slices flows into batches of 20 per Queueable transaction to provide fresh governor limits (CPU, heap, callouts).                                   |
| **Persistence & Storage Layer** | `Flow_Scan__c`, `Flow_Scan_Result__c`, `FHCUninstallHandler.cls` | Stores scan summaries and rule violations natively in custom objects; purges all package data upon uninstall.                                       |

---

## 3. Detailed Information Flow

```
[Administrator (LWC)]
       │ 1. Click "Run Scan" (AuraEnabled POST)
       ▼
[FlowScannerService.initiateAsyncScan()]
       │ 2. Pre-flight CRUD Check (isCreateable on Flow_Scan__c)
       │ 3. Execute Page.SessionHelper.getContent() -> retrieve API Session ID
       │ 4. Insert Flow_Scan__c (Status = 'Pending')
       │ 5. Enqueue FlowScanQueueable(scanId, sessionId)
       ▼
[FlowScanQueueable Worker]
       │ 6. Tooling API Query: SELECT FlowDefinition WHERE ActiveVersionId != null
       │ 7. Partition into batches (BATCH_SIZE = 20)
       │ 8. For each flow: GET /services/data/v61.0/tooling/sobjects/Flow/{ActiveVersionId}
       │ 9. Parse JSON -> FlowWrapper -> Evaluate 12 Active Rules -> Accumulate Violations
       │ 10. If remaining flows > 0 -> Enqueue FlowScanBatchQueueable
       ▼
[Final Batch Persistence]
       │ 11. Calculate Health Score: max(0, 100 - (errors * 60% / total) - (warnings * 20% / total))
       │ 12. Update Flow_Scan__c (Status = 'Complete', Score, Counts)
       │ 13. Insert Flow_Scan_Result__c records
       ▼
[LWC Polling Loop]
       │ 14. Detects Status = 'Complete'
       │ 15. getScanResults(scanId) -> Render Interactive Dashboard & Grouped Violations
```

---

## 4. Authentication & Identity Management

- **Server-Side Session Acquisition**: `UserInfo.getSessionId()` called within `@AuraEnabled` Lightning context returns a restricted UI token that Salesforce blocks from accessing the REST Tooling API (`INVALID_SESSION_ID`). Flow Health Checker uses `SessionHelper.page` (`{!$Api.Session_ID}`) evaluated via `PageReference.getContent()` strictly on the server side.
- **Volatile In-Memory Lifecycle**: The session token is passed directly into asynchronous `Queueable` constructors in memory. It is **never** saved to database objects, custom settings, cookies, browser local storage, or system debug logs.
- **Zero Client Exposure**: The session token is never returned to the Lightning Web Component JavaScript layer.
- **Enterprise Named Credentials**: Supports standard Salesforce Named Credentials (`callout:FlowHealthToolingApi`) for enterprise environments with strict outbound callout policies.
- **Role-Based Access Control**:
  - `FHC_Admin`: Granted execution rights on scanner classes, read/create/edit on `Flow_Scan__c`, and access to `SessionHelper.page`.
  - `FHC_Viewer`: Granted strictly read-only access to scan summary and result objects.

---

## 5. Encryption on Data Transfer & Network Security

- **100% In-Transit Encryption (TLS 1.2+ HTTPS)**: All internal loopback callouts to `URL.getOrgDomainUrl().toExternalForm()` use HTTPS exclusively.
- **Server-Side Request Forgery (SSRF) Whitelisting**: `FlowMetadataService.buildToolingRequest()` validates that the destination endpoint strictly contains `.salesforce.com` or `.force.com` before executing any request.
- **Zero External Data Egress**: The package makes zero callouts to external third-party servers, remote CDNs, or external cloud infrastructure.
- **At-Rest Data Encryption**: Scan records stored in `Flow_Scan__c` and `Flow_Scan_Result__c` inherit native Salesforce database encryption and are fully compatible with Salesforce Shield Platform Encryption.

---

## 6. Data Touchpoints & Schema Model

| Touchpoint                | Type                 | Access Mode          | Data Handled & Purpose                                                                                                                  |
| ------------------------- | -------------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `FlowDefinition` & `Flow` | Platform Tooling API | Read-Only (HTTPS)    | Inspects active Flow definitions, element structures, connector targets, loops, screen fields, and fault paths.                         |
| `Flow_Scan__c`            | Custom Object        | Read / Create / Edit | Stores scan metadata: scan date, status, health score, total flows scanned, total violations, error/warning counts, and error messages. |
| `Flow_Scan_Result__c`     | Custom Object        | Read / Create        | Stores individual rule violations: flow API name, rule name, severity, element name, description, and flow definition ID.               |
| `Flow_Rule__mdt`          | Custom Metadata Type | Read-Only (SOQL)     | Defines the catalog of inspection rules: rule type, severity, active flag, and rule descriptions.                                       |

---

## 7. Basic Usage & Administrator Instructions

### Step 1: Install the Package

Install the managed package into your Salesforce org using the AppExchange installation link or via Salesforce CLI:

```bash
sf package install --package "04tdL000000o6obQAA" --wait 10 --target-org <target-org-alias>
```

### Step 2: Assign Permission Sets

- **For Administrators**: Assign `Flow Health Checker Admin` (`FHC_Admin`).
- **For Auditors / QA**: Assign `Flow Health Checker Viewer` (`FHC_Viewer`).

### Step 3: Launch the Application

1. Open the Salesforce App Launcher (waffle icon).
2. Search for and select **Flow Health Checker**.

### Step 4: Run a Health Scan

1. Click the **▶ Run Scan** button in the header.
2. The scanner runs asynchronously in the background (typically 5 to 20 seconds).
3. The dashboard automatically updates upon completion with the Health Score and violation metrics.

### Step 5: Review & Remediate Violations

- Use the **Severity Filters** (`Errors`, `Warnings`, `Info`) to prioritize high-risk items.
- Click any **Flow Accordion** to inspect specific element violations.
- Click the **↗ Open Flow** button to open Salesforce Flow Builder directly in a new tab for immediate remediation.

### Step 6: Review Rules & Historical Trends

- Click **📋 View Rules** to review descriptions, severities, and rationales for all 12 active rules.
- Click **📈 History** to track health score trends across historical scans.
