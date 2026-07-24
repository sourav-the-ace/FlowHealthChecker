public with sharing class FlowScanQueueable
    implements Queueable, Database.AllowsCallouts {

    private Id scanId;
    private static final Integer BATCH_SIZE = 20;

    public FlowScanQueueable(Id scanId) {
        this.scanId = scanId;
    }

    public void execute(QueueableContext context) {
        try {
            String sessionId = UserInfo.getSessionId();

            List<Map<String, Object>> flowDefinitions =
                FlowMetadataService.fetchFlowDefinitions(sessionId);

            if (flowDefinitions.isEmpty()) {
                FlowScannerService.persistScanResults(
                    scanId, 0, new List<RuleViolation>()
                );
                markComplete();
                return;
            }

            // Split into first batch and remainder
            List<Map<String, Object>> firstBatch    = new List<Map<String, Object>>();
            List<Map<String, Object>> remainingFlows = new List<Map<String, Object>>();

            for (Integer i = 0; i < flowDefinitions.size(); i++) {
                if (i < BATCH_SIZE) {
                    firstBatch.add(flowDefinitions[i]);
                } else {
                    remainingFlows.add(flowDefinitions[i]);
                }
            }

            // Process first batch inline
            List<IFlowRule> activeRules = FlowScannerService.loadRules();
            List<RuleViolation> violations = new List<RuleViolation>();

            for (Map<String, Object> flowRec : firstBatch) {
                try {
                    FlowWrapper flow =
                        FlowMetadataService.fetchSingleFlow(flowRec, sessionId);
                    if (flow == null) continue;
                    for (IFlowRule rule : activeRules) {
                        List<RuleViolation> flowViolations = rule.evaluate(flow);
                        for (RuleViolation v : flowViolations) {
                            v.flowDefinitionId = flow.flowDefinitionId;
                        }
                        violations.addAll(flowViolations);
                    }
                } catch (Exception flowEx) {
                    System.debug(LoggingLevel.WARN,
                        'Error processing flow: ' + flowEx.getMessage());
                }
            }

            if (!remainingFlows.isEmpty()) {
                System.enqueueJob(new FlowScanBatchQueueable(
                    scanId, remainingFlows, violations, flowDefinitions.size()
                ));
            } else {
                FlowScannerService.persistScanResults(
                    scanId, flowDefinitions.size(), violations
                );
                markComplete();
            }

        } catch (Exception ex) {
            markFailed(ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private void markComplete() {
        update new Flow_Scan__c(
            Id        = scanId,
            Status__c = 'Complete'
        );
    }

    private void markFailed(String errorMessage) {
        update new Flow_Scan__c(
            Id               = scanId,
            Status__c        = 'Failed',
            Error_Message__c = errorMessage
        );
    }
}