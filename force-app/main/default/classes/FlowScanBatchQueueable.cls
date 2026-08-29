public with sharing class FlowScanBatchQueueable implements Queueable, Database.AllowsCallouts {
  private Id scanId;
  private List<Map<String, Object>> pendingFlows;
  private List<RuleViolation> accumulatedViolations;
  private Integer totalFlowsCount;
  private String sessionId;
  private static final Integer BATCH_SIZE = 20;

  public FlowScanBatchQueueable(
    Id scanId,
    List<Map<String, Object>> pendingFlows,
    List<RuleViolation> accumulatedViolations,
    Integer totalFlowsCount
  ) {
    this(
      scanId,
      pendingFlows,
      accumulatedViolations,
      totalFlowsCount,
      FlowScannerService.getApiSessionId()
    );
  }

  public FlowScanBatchQueueable(
    Id scanId,
    List<Map<String, Object>> pendingFlows,
    List<RuleViolation> accumulatedViolations,
    Integer totalFlowsCount,
    String sessionId
  ) {
    this.scanId = scanId;
    this.pendingFlows = pendingFlows;
    this.accumulatedViolations = accumulatedViolations;
    this.totalFlowsCount = totalFlowsCount;
    this.sessionId = sessionId;
  }

  public void execute(QueueableContext context) {
    try {
      String effectiveSessionId = String.isNotBlank(this.sessionId)
        ? this.sessionId
        : FlowScannerService.getApiSessionId();
      List<IFlowRule> activeRules = FlowScannerService.loadRules();

      Integer batchEnd = Math.min(BATCH_SIZE, pendingFlows.size());
      List<Map<String, Object>> currentBatch = new List<Map<String, Object>>();
      List<Map<String, Object>> remainingFlows = new List<Map<String, Object>>();

      for (Integer i = 0; i < pendingFlows.size(); i++) {
        if (i < batchEnd) {
          currentBatch.add(pendingFlows[i]);
        } else {
          remainingFlows.add(pendingFlows[i]);
        }
      }

      for (Map<String, Object> flowRec : currentBatch) {
        try {
          FlowWrapper flow = FlowMetadataService.fetchSingleFlow(
            flowRec,
            effectiveSessionId
          );
          if (flow == null)
            continue;
          for (IFlowRule rule : activeRules) {
            List<RuleViolation> flowViolations = rule.evaluate(flow);
            for (RuleViolation v : flowViolations) {
              v.flowDefinitionId = flow.flowDefinitionId;
            }
            accumulatedViolations.addAll(flowViolations);
          }
        } catch (Exception flowEx) {
          System.debug(
            LoggingLevel.WARN,
            'Error processing flow: ' + flowEx.getMessage()
          );
        }
      }

      if (!remainingFlows.isEmpty()) {
        System.enqueueJob(
          new FlowScanBatchQueueable(
            scanId,
            remainingFlows,
            accumulatedViolations,
            totalFlowsCount,
            effectiveSessionId
          )
        );
      } else {
        FlowScannerService.persistScanResults(
          scanId,
          totalFlowsCount,
          accumulatedViolations
        );
        update new Flow_Scan__c(Id = scanId, Status__c = 'Complete');
      }
    } catch (Exception ex) {
      update new Flow_Scan__c(
        Id = scanId,
        Status__c = 'Failed',
        Error_Message__c = ex.getMessage() + '\n' + ex.getStackTraceString()
      );
    }
  }
}
