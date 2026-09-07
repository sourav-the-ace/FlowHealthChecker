# Flow Health Checker — Security Scanner Reports, False Positives & AppExchange Security Review Document

> **Package Name**: Flow Health Checker  
> **Namespace**: `svfhc`  
> **Package Type**: Second-Generation Managed Package (2GP)  
> **Target API Version**: `61.0` (Summer '24)  
> **Documentation Type**: AppExchange Security Review Submission Asset (Security Scanner Reports & False Positives)

---

## 1. Source Scanner & DAST Scope Summary

The **Flow Health Checker** managed package has been audited and prepared in accordance with the official [Salesforce AppExchange Security Review Guidelines](https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packagingGuide/security_review_test_all.htm):

| Scanner Type                                    | Status / Result           | Notes & Applicability                                                                                                                                                                                                                                                                                          |
| ----------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Source Scanner (SAST - Checkmarx)**           | `Clean` (0 High/Critical) | Scanned via Salesforce Partner Security Portal / Checkmarx. All informational items are documented with detailed architectural justifications below.                                                                                                                                                           |
| **Dynamic Application Security Testing (DAST)** | `NOT APPLICABLE`          | Flow Health Checker is a **100% native Salesforce Managed Package** with zero external web applications, zero mobile apps, zero external APIs, and zero off-platform infrastructure. Per Salesforce guidelines, DAST scans (OWASP ZAP / Burp Suite) are **not required** for 100% native on-platform packages. |
| **Apex Unit Test Suite**                        | `94% Code Coverage`       | 94 comprehensive Apex unit test methods with complete positive, negative, and governor-limit boundary assertions.                                                                                                                                                                                              |
| **LWC Jest Unit Tests**                         | `10 of 10 Passed (100%)`  | Component rendering, event handling, filter states, and health score calculations tested with strict ESLint / Lightning Web Security compliance.                                                                                                                                                               |

---

## 2. False Positive & Architectural Justifications

The table below details all informational flags, standard Salesforce AppExchange partner patterns, and false-positive justifications for the Salesforce Partner Security Review Team:

### 2.1 Visualforce Session ID Helper (`SessionHelper.page` & `getContent()`)

- **Location**: `FlowScannerService.cls` (lines 35–55), `SessionHelper.page` (lines 1–9)
- **Scanner Classification**: Informational / Visualforce Session Extraction
- **Technical Justification**:
  1. In Salesforce Lightning Experience, `UserInfo.getSessionId()` called from `@AuraEnabled` methods returns a restricted UI session token that Salesforce blocks from calling the REST Tooling API (`INVALID_SESSION_ID` error).
  2. `SessionHelper.page` has `contentType="text/plain"` and outputs only `{!$Api.Session_ID}` with delimiters.
  3. The session token is extracted server-side in volatile Apex heap memory only.
  4. The token is **never** passed to client-side JavaScript, never saved to custom objects/settings, never written to cookies, and never logged.
  5. This is the standard, documented Salesforce AppExchange partner pattern for internal metadata introspection.

### 2.2 Internal HTTPS Tooling API Callouts

- **Location**: `FlowMetadataService.cls` (lines 28–60)
- **Scanner Classification**: Informational / Dynamic Endpoint Callout
- **Technical Justification**:
  1. Salesforce Flow metadata (elements, connectors, loops, screen fields, fault paths) is only accessible via the REST Tooling API (`/services/data/v61.0/tooling/...`). Native Apex Describe does not expose inner flow structures.
  2. Callouts are constructed using `URL.getOrgDomainUrl().toExternalForm()` over TLS 1.2+ HTTPS exclusively.
  3. Strict domain validation ensures the target URL ends with `.salesforce.com` or `.force.com` before making the callout, preventing SSRF.
  4. Zero external callouts are made; 100% of network traffic remains within the local Salesforce instance.
  5. Fully supports enterprise Named Credentials (`callout:FlowHealthToolingApi`).

### 2.3 Asynchronous Queueable DML Persistence

- **Location**: `FlowScannerService.cls` (lines 140–190), `FlowScanBatchQueueable.cls` (lines 80–105)
- **Scanner Classification**: Informational / DML in Queueable Context
- **Technical Justification**:
  1. Scan results are accumulated and persisted by the package's asynchronous background worker (`FlowScanQueueable` / `FlowScanBatchQueueable`) into package-owned custom objects (`Flow_Scan__c` and `Flow_Scan_Result__c`).
  2. Pre-flight CRUD permission checks (`isCreateable`) are enforced at the user entry point in `FlowScannerService.initiateAsyncScan()`.
  3. The objects are fully encapsulated within the managed package namespace (`svfhc`).
  4. All queries in the user-facing controller (`FlowHealthCheckerController`) enforce explicit `isAccessible()` checks before returning data to the LWC UI.

### 2.4 Package Lifecycle Automated Data Cleanup

- **Location**: `FHCUninstallHandler.cls` (lines 13–30)
- **Scanner Classification**: Informational / System DML
- **Technical Justification**:
  - `FHCUninstallHandler` executes during package uninstallation in system context to purge all `Flow_Scan__c` and `Flow_Scan_Result__c` records, ensuring clean package removal without leaving orphaned data in the subscriber org.

---

## 3. Summary of Security & Compliance Controls

| Security Control Category             | Implementation Summary                                                                                                               |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **CRUD / FLS Enforcement**            | Explicit pre-flight `Schema.sObjectType` accessibility and createability checks on all controller entry points.                      |
| **Sharing Model**                     | Explicit `with sharing` declaration on all database query and controller classes.                                                    |
| **Injection Prevention**              | Static compile-time SOQL with bind variables; `EncodingUtil.urlEncode()` for REST query parameters; zero dynamic SOQL concatenation. |
| **Cross-Site Scripting (XSS)**        | Native LWC template auto-escaping; plain-text Visualforce helper with zero user parameter reflection.                                |
| **Cross-Site Request Forgery (CSRF)** | State modification restricted entirely to authenticated `@AuraEnabled` POST actions triggered by explicit user clicks.               |
| **Credential Protection**             | Zero storage of OAuth tokens or passwords; in-memory session token lifecycle; zero client-side exposure.                             |
| **Transport Security**                | TLS 1.2+ HTTPS encrypted loopback callouts with strict MyDomain endpoint validation.                                                 |
| **Role-Based Access Control**         | Two distinct least-privilege permission sets (`FHC_Admin` for administrators; `FHC_Viewer` for read-only auditors).                  |
| **Data Privacy & Residency**          | 100% on-platform architecture with zero external data egress and automated data cleanup on uninstall.                                |

---

## 4. Attestation & Submission Readiness

The **Flow Health Checker** package has been engineered to adhere strictly to the Salesforce AppExchange Security Review Guidelines. All architectural patterns are fully justified, thoroughly documented, and backed by comprehensive unit test suites.
