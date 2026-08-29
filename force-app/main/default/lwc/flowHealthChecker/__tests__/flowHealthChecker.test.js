import { createElement } from "lwc";
import FlowHealthChecker from "c/flowHealthChecker";
import initiateAsyncScan from "@salesforce/apex/FlowScannerService.initiateAsyncScan";
import getScanStatus from "@salesforce/apex/FlowScannerService.getScanStatus";
import getScanResults from "@salesforce/apex/FlowHealthCheckerController.getScanResults";
import getRules from "@salesforce/apex/FlowHealthCheckerController.getRules";
import getScanHistory from "@salesforce/apex/FlowHealthCheckerController.getScanHistory";
import { NavigationMixin } from "lightning/navigation";

jest.mock(
  "@salesforce/apex/FlowScannerService.initiateAsyncScan",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FlowScannerService.getScanStatus",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FlowHealthCheckerController.getScanResults",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FlowHealthCheckerController.getRules",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FlowHealthCheckerController.getScanHistory",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const MOCK_SCAN_RESULTS = {
  scan: {
    Id: "a00000000000001AAA",
    Scan_Date__c: "2026-08-28T10:00:00.000Z",
    Total_Flows_Scanned__c: 5,
    Total_Violations__c: 2,
    Errors__c: 1,
    Warnings__c: 1,
    Affected_Flows__c: 2,
    Health_Score__c: 84.0,
    Status__c: "Complete"
  },
  results: [
    {
      Id: "a01000000000001AAA",
      svfhc__Flow_API_Name__c: "Account_Trigger_Flow",
      svfhc__Rule_Name__c: "DML In Loop",
      svfhc__Severity__c: "Error",
      svfhc__Element_Name__c: "Update_Account_Record",
      svfhc__Description__c: "DML statement executed inside loop.",
      svfhc__Flow_Definition_Id__c: "300000000000001AAA"
    },
    {
      Id: "a01000000000002AAA",
      svfhc__Flow_API_Name__c: "Opportunity_Notification_Flow",
      svfhc__Rule_Name__c: "Missing Description",
      svfhc__Severity__c: "Warning",
      svfhc__Element_Name__c: "Opportunity_Notification_Flow",
      svfhc__Description__c: "Flow has no description.",
      svfhc__Flow_Definition_Id__c: "300000000000002AAA"
    }
  ]
};

const MOCK_RULES = [
  {
    MasterLabel: "DML In Loop",
    Severity__c: "Error",
    Active__c: true,
    Description__c: "Flags DML inside loops.",
    Rule_Type__c: "DmlInLoopRule"
  },
  {
    MasterLabel: "Missing Description",
    Severity__c: "Warning",
    Active__c: true,
    Description__c: "Flags flows missing descriptions.",
    Rule_Type__c: "MissingDescriptionRule"
  }
];

const MOCK_HISTORY = [
  {
    Id: "a00000000000001AAA",
    Scan_Date__c: "2026-08-28T10:00:00.000Z",
    Total_Flows_Scanned__c: 5,
    Errors__c: 1,
    Warnings__c: 1,
    Health_Score__c: 84.0,
    Status__c: "Complete"
  },
  {
    Id: "a00000000000002AAA",
    Scan_Date__c: "2026-08-27T10:00:00.000Z",
    Total_Flows_Scanned__c: 5,
    Errors__c: 0,
    Warnings__c: 0,
    Health_Score__c: 100.0,
    Status__c: "Complete"
  }
];

async function flushPromises() {
  return Promise.resolve();
}

describe("c-flow-health-checker", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders initial default state correctly", () => {
    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    const title = element.shadowRoot.querySelector(".fhc-page-title");
    expect(title).not.toBeNull();
    expect(title.textContent).toBe("Flow Health Checker");

    const initState = element.shadowRoot.querySelector(".fhc-init-state");
    expect(initState).not.toBeNull();

    const cards = element.shadowRoot.querySelectorAll(".fhc-card-val");
    expect(cards.length).toBe(5);
    cards.forEach((card) => {
      expect(
        ["-", "0%", "0", ""].some((val) => card.textContent.includes(val))
      ).toBe(true);
    });
  });

  it("executes scan and displays results on poll completion", async () => {
    initiateAsyncScan.mockResolvedValue("a00000000000001AAA");
    getScanStatus.mockResolvedValue({
      status: "Complete",
      errorMessage: null,
      totalFlows: 5,
      totalViolations: 2
    });
    getScanResults.mockResolvedValue(MOCK_SCAN_RESULTS);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    const scanBtn = element.shadowRoot.querySelector(".fhc-btn-primary");
    scanBtn.click();

    await flushPromises();
    expect(initiateAsyncScan).toHaveBeenCalled();

    // Advance timer for polling
    jest.advanceTimersByTime(3000);
    await flushPromises();
    await flushPromises();

    expect(getScanStatus).toHaveBeenCalledWith({
      scanId: "a00000000000001AAA"
    });
    expect(getScanResults).toHaveBeenCalledWith({
      scanId: "a00000000000001AAA"
    });

    const groups = element.shadowRoot.querySelectorAll(".fhc-flow-group");
    expect(groups.length).toBe(2);

    const metaBar = element.shadowRoot.querySelector(".fhc-meta-bar");
    expect(metaBar.textContent).toContain(
      "Showing 2 violations across 2 flows"
    );
  });

  it("handles scan failure and displays error banner", async () => {
    initiateAsyncScan.mockResolvedValue("a00000000000001AAA");
    getScanStatus.mockResolvedValue({
      status: "Failed",
      errorMessage: "Tooling API timeout",
      totalFlows: 0,
      totalViolations: 0
    });

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    const scanBtn = element.shadowRoot.querySelector(".fhc-btn-primary");
    scanBtn.click();

    await flushPromises();
    jest.advanceTimersByTime(3000);
    await flushPromises();

    const errBanner = element.shadowRoot.querySelector(".fhc-error-banner");
    expect(errBanner).not.toBeNull();
    expect(errBanner.textContent).toContain("Scan failed: Tooling API timeout");
  });

  it("filters flow groups by severity button clicks", async () => {
    initiateAsyncScan.mockResolvedValue("a00000000000001AAA");
    getScanStatus.mockResolvedValue({ status: "Complete" });
    getScanResults.mockResolvedValue(MOCK_SCAN_RESULTS);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    element.shadowRoot.querySelector(".fhc-btn-primary").click();
    await flushPromises();
    jest.advanceTimersByTime(3000);
    await flushPromises();
    await flushPromises();

    // Click Error filter
    const errorFilterBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-filter-btn")
    ).find((btn) => btn.textContent.includes("Error"));
    errorFilterBtn.click();
    await flushPromises();

    let groups = element.shadowRoot.querySelectorAll(".fhc-flow-group");
    expect(groups.length).toBe(1);
    expect(groups[0].textContent).toContain("Account_Trigger_Flow");

    // Click Warning filter
    const warnFilterBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-filter-btn")
    ).find((btn) => btn.textContent.includes("Warning"));
    warnFilterBtn.click();
    await flushPromises();

    groups = element.shadowRoot.querySelectorAll(".fhc-flow-group");
    expect(groups.length).toBe(1);
    expect(groups[0].textContent).toContain("Opportunity_Notification_Flow");

    // Click All filter
    const allFilterBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-filter-btn")
    ).find((btn) => btn.textContent === "All");
    allFilterBtn.click();
    await flushPromises();

    groups = element.shadowRoot.querySelectorAll(".fhc-flow-group");
    expect(groups.length).toBe(2);
  });

  it("filters flow groups by search input", async () => {
    initiateAsyncScan.mockResolvedValue("a00000000000001AAA");
    getScanStatus.mockResolvedValue({ status: "Complete" });
    getScanResults.mockResolvedValue(MOCK_SCAN_RESULTS);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    element.shadowRoot.querySelector(".fhc-btn-primary").click();
    await flushPromises();
    jest.advanceTimersByTime(3000);
    await flushPromises();
    await flushPromises();

    const searchInput = element.shadowRoot.querySelector(".fhc-search-input");
    searchInput.value = "Opportunity";
    searchInput.dispatchEvent(new CustomEvent("input"));
    await flushPromises();

    const groups = element.shadowRoot.querySelectorAll(".fhc-flow-group");
    expect(groups.length).toBe(1);
    expect(groups[0].textContent).toContain("Opportunity_Notification_Flow");
  });

  it("toggles flow group expansion and handles expand/collapse all", async () => {
    initiateAsyncScan.mockResolvedValue("a00000000000001AAA");
    getScanStatus.mockResolvedValue({ status: "Complete" });
    getScanResults.mockResolvedValue(MOCK_SCAN_RESULTS);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    element.shadowRoot.querySelector(".fhc-btn-primary").click();
    await flushPromises();
    jest.advanceTimersByTime(3000);
    await flushPromises();
    await flushPromises();

    // Initially all are expanded
    let tables = element.shadowRoot.querySelectorAll(".fhc-viol-table");
    expect(tables.length).toBe(2);

    // Click collapse all
    const collapseBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-exp-btn")
    ).find((btn) => btn.textContent.includes("Collapse all"));
    collapseBtn.click();
    await flushPromises();

    tables = element.shadowRoot.querySelectorAll(".fhc-viol-table");
    expect(tables.length).toBe(0);

    // Click individual header to expand
    const headerLeft = element.shadowRoot.querySelector(".fhc-flow-hdr-left");
    headerLeft.click();
    await flushPromises();

    tables = element.shadowRoot.querySelectorAll(".fhc-viol-table");
    expect(tables.length).toBe(1);

    // Keyboard navigation (Enter / Space key)
    headerLeft.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await flushPromises();
    tables = element.shadowRoot.querySelectorAll(".fhc-viol-table");
    expect(tables.length).toBe(0);

    // Click expand all
    const expandBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-exp-btn")
    ).find((btn) => btn.textContent.includes("Expand all"));
    expandBtn.click();
    await flushPromises();

    tables = element.shadowRoot.querySelectorAll(".fhc-viol-table");
    expect(tables.length).toBe(2);
  });

  it("renders Open Flow button for flows with definition id and triggers navigation logic", async () => {
    initiateAsyncScan.mockResolvedValue("a00000000000001AAA");
    getScanStatus.mockResolvedValue({ status: "Complete" });
    getScanResults.mockResolvedValue(MOCK_SCAN_RESULTS);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    element.shadowRoot.querySelector(".fhc-btn-primary").click();
    await flushPromises();
    jest.advanceTimersByTime(3000);
    await flushPromises();
    await flushPromises();

    const openFlowBtn = element.shadowRoot.querySelector(".fhc-flow-link-btn");
    expect(openFlowBtn).not.toBeNull();
    expect(openFlowBtn.dataset.id).toBe("300000000000001AAA");

    // Test navigation mixin call logic directly
    const navigateMock = jest.fn();
    const ctx = {
      [NavigationMixin.Navigate]: navigateMock
    };
    FlowHealthChecker.prototype.handleOpenFlow.call(ctx, {
      currentTarget: { dataset: { id: "300000000000001AAA" } }
    });
    expect(navigateMock).toHaveBeenCalledWith({
      type: "standard__webPage",
      attributes: {
        url: "/builder_platform_interaction/flowBuilder.app?flowDefId=300000000000001AAA"
      }
    });
  });

  it("opens and closes Rules modal", async () => {
    getRules.mockResolvedValue(MOCK_RULES);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    const rulesBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-btn-secondary")
    ).find((btn) => btn.textContent.includes("View Rules"));
    rulesBtn.click();
    await flushPromises();

    expect(getRules).toHaveBeenCalled();
    let modal = element.shadowRoot.querySelector(".fhc-modal");
    expect(modal).not.toBeNull();
    expect(modal.textContent).toContain("Flow Health Rules");

    // Close modal
    element.shadowRoot.querySelector(".fhc-modal-close").click();
    await flushPromises();

    modal = element.shadowRoot.querySelector(".fhc-modal");
    expect(modal).toBeNull();
  });

  it("opens and closes History modal", async () => {
    getScanHistory.mockResolvedValue(MOCK_HISTORY);

    const element = createElement("c-flow-health-checker", {
      is: FlowHealthChecker
    });
    document.body.appendChild(element);

    const historyBtn = Array.from(
      element.shadowRoot.querySelectorAll(".fhc-btn-secondary")
    ).find((btn) => btn.textContent.includes("History"));
    historyBtn.click();
    await flushPromises();

    expect(getScanHistory).toHaveBeenCalledWith({ maxRecords: 20 });
    let modal = element.shadowRoot.querySelector(".fhc-modal");
    expect(modal).not.toBeNull();
    expect(modal.textContent).toContain("Health Score Trend");

    // Close modal
    element.shadowRoot.querySelector(".fhc-modal-close").click();
    await flushPromises();

    modal = element.shadowRoot.querySelector(".fhc-modal");
    expect(modal).toBeNull();
  });

  it("correctly calculates health score mathematically", () => {
    const computeFn = FlowHealthChecker.prototype.computeHealthScore;

    // 0 violations in 10 flows -> 100%
    expect(computeFn(10, 0, 0)).toBe(100);

    // 1 error, 1 warning in 5 flows -> 100 - (1*20*0.6) - (1*20*0.2) = 100 - 12 - 4 = 84%
    expect(computeFn(5, 1, 1)).toBe(84);

    // Over-penalized -> minimum 0%
    expect(computeFn(1, 10, 10)).toBe(0);

    // Default 0 flows -> safely handled as 1 flow
    expect(computeFn(0, 0, 0)).toBe(100);
  });
});
