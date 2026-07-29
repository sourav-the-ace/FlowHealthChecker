public with sharing class FlowMetadataService {

    public static List<FlowWrapper> fetchAllFlows(String sessionId) {
        List<FlowWrapper> flows = new List<FlowWrapper>();
        String baseUrl    = URL.getOrgDomainUrl().toExternalForm();
        String apiVersion = '61.0';
        
        // Validate org domain — must be a Salesforce domain
        if (!baseUrl.containsIgnoreCase('.salesforce.com')
            && !baseUrl.containsIgnoreCase('.force.com')) {
            throw new FlowScannerException(
                'Unexpected org domain: ' + baseUrl
            );
        }

        String soql = EncodingUtil.urlEncode(
            'SELECT Id, DeveloperName, MasterLabel, Description, ActiveVersionId '
            + 'FROM FlowDefinition WHERE ActiveVersionId != null', 'UTF-8'
        );

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/services/data/v' + apiVersion
                        + '/tooling/query?q=' + soql);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new FlowScannerException(
                'Tooling API query failed: ' + res.getStatus() + ' ' + res.getBody()
            );
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) responseMap.get('records');

        for (Object rec : records) {
            Map<String, Object> flowRec       = (Map<String, Object>) rec;
            String activeVersionId = (String) flowRec.get('ActiveVersionId');
            String definitionId    = (String) flowRec.get('Id');

            if (String.isBlank(activeVersionId)) continue;
            if (!isValidSalesforceId(activeVersionId)) continue;
            if (!isValidSalesforceId(definitionId)) continue;

            // Sanitize string fields from API response
            String developerName = String.valueOf(flowRec.get('DeveloperName'));
            String masterLabel   = String.valueOf(flowRec.get('MasterLabel'));
            String description   = flowRec.get('Description') != null
                ? String.valueOf(flowRec.get('Description')) : null;

            FlowWrapper flow = fetchFlowMetadata(
                baseUrl, apiVersion, activeVersionId,
                developerName, masterLabel, description,
                definitionId, sessionId
            );
            if (flow != null) flows.add(flow);
        }
        return flows;
    }

    private static FlowWrapper fetchFlowMetadata(
            String baseUrl, String apiVersion, String versionId,
            String apiName, String label, String description,
            String definitionId, String sessionId
        ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/services/data/v' + apiVersion
                        + '/tooling/sobjects/Flow/' + versionId + '?fields=Metadata');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) return null;

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> metadata =
            (Map<String, Object>) body.get('Metadata');
        if (metadata == null) return null;

        FlowWrapper flow    = new FlowWrapper();
        flow.flowApiName    = apiName;
        flow.flowLabel      = label;
        flow.description    = description;
        flow.processType      = (String) metadata.get('processType');
        flow.flowDefinitionId = definitionId;
        flow.elements         = parseElements(metadata);

        // Phase 2 additions
        flow.variables         = parseVariables(metadata);
        flow.subflows          = parseSubflows(metadata);
        flow.connectedElements = buildConnectedSet(metadata, flow.elements);
        flow.startConfig       = parseStart(metadata);

        return flow;
    }

    // ── Phase 1 — unchanged ──────────────────────────────────────

    private static List<FlowWrapper.FlowElementWrapper> parseElements(
    Map<String, Object> metadata
    ) {
        List<FlowWrapper.FlowElementWrapper> elements =
            new List<FlowWrapper.FlowElementWrapper>();

        // Build loop-to-element map
        Map<String, String> elementToLoop = new Map<String, String>();
        List<Object> loops = (List<Object>) metadata.get('loops');
        if (loops != null) {
            for (Object loopObj : loops) {
                Map<String, Object> loopRecord = (Map<String, Object>) loopObj;
                String loopName = (String) loopRecord.get('name');
                Map<String, Object> nextConn =
                    (Map<String, Object>) loopRecord.get('nextValueConnector');
                if (nextConn != null) {
                    elementToLoop.put(
                        (String) nextConn.get('targetReference'), loopName
                    );
                }
            }
        }

        // Build fault path set — collect all elements reachable via fault connectors
        Set<String> faultPathElements = new Set<String>();
        Map<String, String> elementTypeKeys = new Map<String, String>{
            'recordCreates'   => 'RecordCreate',
            'recordUpdates'   => 'RecordUpdate',
            'recordDeletes'   => 'RecordDelete',
            'recordLookups'   => 'RecordLookup',
            'actionCalls'     => 'ActionCall',
            'apexPluginCalls' => 'ApexPluginCall',
            'loops'           => 'Loop',
            'assignments'     => 'Assignment',
            'decisions'       => 'Decision',
            'screens'         => 'Screen'   
        };

        // First pass — collect fault connector targets
        for (String key : elementTypeKeys.keySet()) {
            List<Object> items = (List<Object>) metadata.get(key);
            if (items == null) continue;
            for (Object item : items) {
                Map<String, Object> el = (Map<String, Object>) item;
                Map<String, Object> faultConn =
                    (Map<String, Object>) el.get('faultConnector');
                if (faultConn != null) {
                    String target = (String) faultConn.get('targetReference');
                    if (String.isNotBlank(target)) {
                        faultPathElements.add(target);
                    }
                }
            }
        }

        // Also collect fault targets from subflows
        List<Object> subflows = (List<Object>) metadata.get('subflows');
        if (subflows != null) {
            for (Object item : subflows) {
                Map<String, Object> el = (Map<String, Object>) item;
                Map<String, Object> faultConn =
                    (Map<String, Object>) el.get('faultConnector');
                if (faultConn != null) {
                    String target = (String) faultConn.get('targetReference');
                    if (String.isNotBlank(target)) {
                        faultPathElements.add(target);
                    }
                }
            }
        }

        // Second pass — build element wrappers with isOnFaultPath populated
        for (String key : elementTypeKeys.keySet()) {
            List<Object> items = (List<Object>) metadata.get(key);
            if (items == null) continue;

            for (Object item : items) {
                Map<String, Object> el = (Map<String, Object>) item;
                FlowWrapper.FlowElementWrapper wrapper =
                    new FlowWrapper.FlowElementWrapper();

                wrapper.name           = (String) el.get('name');
                wrapper.elementType    = elementTypeKeys.get(key);
                wrapper.parentLoopName = elementToLoop.get(wrapper.name);
                wrapper.isOnFaultPath  = faultPathElements.contains(wrapper.name);

                Map<String, Object> faultConn =
                    (Map<String, Object>) el.get('faultConnector');
                wrapper.hasFaultConnector = (faultConn != null);
                wrapper.rawValue          = JSON.serialize(el);
                // 2. In the element-wrapper build loop, after wrapper.rawValue is set:
                if (wrapper.elementType == 'Screen') {
                    List<Object> fields = (List<Object>) el.get('fields');
                    wrapper.fieldCount  = fields != null ? fields.size() : 0;
                }                
                if (el.containsKey('object')) {
                    wrapper.objectName = (String) el.get('object');
                }

                elements.add(wrapper);
            }
        }
        return elements;
    }

    // ── Phase 2 — new parsers ────────────────────────────────────

    private static List<FlowWrapper.FlowVariableWrapper> parseVariables(
        Map<String, Object> metadata
    ) {
        List<FlowWrapper.FlowVariableWrapper> variables =
            new List<FlowWrapper.FlowVariableWrapper>();

        List<Object> vars = (List<Object>) metadata.get('variables');
        if (vars == null) return variables;

        for (Object varObj : vars) {
            Map<String, Object> v = (Map<String, Object>) varObj;
            FlowWrapper.FlowVariableWrapper wrapper =
                new FlowWrapper.FlowVariableWrapper();
            wrapper.name     = (String)  v.get('name');
            wrapper.dataType = (String)  v.get('dataType');
            wrapper.isInput  = v.get('isInput')  == true;
            wrapper.isOutput = v.get('isOutput') == true;
            variables.add(wrapper);
        }
        return variables;
    }

    // 3. In parseSubflows(), capture the called flow's API name:
    private static List<FlowWrapper.FlowElementWrapper> parseSubflows(
        Map<String, Object> metadata
    ) {
        List<FlowWrapper.FlowElementWrapper> subflows =
            new List<FlowWrapper.FlowElementWrapper>();

        List<Object> items = (List<Object>) metadata.get('subflows');
        if (items == null) return subflows;

        for (Object item : items) {
            Map<String, Object> el = (Map<String, Object>) item;
            FlowWrapper.FlowElementWrapper wrapper =
                new FlowWrapper.FlowElementWrapper();
            wrapper.name              = (String) el.get('name');
            wrapper.elementType       = 'Subflow';
            wrapper.calledFlowApiName = (String) el.get('flowName'); // NEW
            wrapper.rawValue          = JSON.serialize(el);

            Map<String, Object> faultConn =
                (Map<String, Object>) el.get('faultConnector');
            wrapper.hasFaultConnector = (faultConn != null);
            subflows.add(wrapper);
        }
        return subflows;
    }

    private static Set<String> buildConnectedSet(
        Map<String, Object> metadata,
        List<FlowWrapper.FlowElementWrapper> elements
    ) {
        // Walk every connector in every element type and collect
        // all targetReferences — these are elements that are reachable
        Set<String> connected = new Set<String>();

        // Start element is always connected
        Map<String, Object> start = (Map<String, Object>) metadata.get('start');
        if (start != null) {
            Map<String, Object> startConn =
                (Map<String, Object>) start.get('connector');
            if (startConn != null) {
                connected.add((String) startConn.get('targetReference'));
            }
        }

        // All element types that can have connectors
        List<String> allKeys = new List<String>{
            'recordCreates', 'recordUpdates', 'recordDeletes', 'recordLookups',
            'actionCalls', 'apexPluginCalls', 'loops', 'assignments',
            'decisions', 'subflows', 'screens', 'customErrors'
        };

        for (String key : allKeys) {
            List<Object> items = (List<Object>) metadata.get(key);
            if (items == null) continue;

            for (Object item : items) {
                Map<String, Object> el = (Map<String, Object>) item;
                String elName = (String) el.get('name');

                // Regular connector
                collectTarget(el, 'connector', connected);

                // Fault connector
                collectTarget(el, 'faultConnector', connected);

                // Decision rules (outcomes)
                List<Object> rules = (List<Object>) el.get('rules');
                if (rules != null) {
                    for (Object rule : rules) {
                        collectTarget((Map<String, Object>) rule, 'connector', connected);
                    }
                }

                // Loop connectors
                collectTarget(el, 'nextValueConnector', connected);
                collectTarget(el, 'noMoreValuesConnector', connected);
            }
        }
        return connected;
    }

    private static void collectTarget(
        Map<String, Object> el, String connectorKey, Set<String> connected
    ) {
        Map<String, Object> conn = (Map<String, Object>) el.get(connectorKey);
        if (conn != null) {
            String target = (String) conn.get('targetReference');
            if (String.isNotBlank(target)) connected.add(target);
        }
    }

    private static FlowWrapper.FlowStartWrapper parseStart(
        Map<String, Object> metadata
    ) {
        Map<String, Object> start = (Map<String, Object>) metadata.get('start');
        if (start == null) return null;

        FlowWrapper.FlowStartWrapper wrapper = new FlowWrapper.FlowStartWrapper();
        wrapper.triggerType       = (String) start.get('triggerType');
        wrapper.objectApiName     = (String) start.get('object');
        wrapper.recordTriggerType = (String) start.get('recordTriggerType');
        return wrapper;
    }
    private static Boolean isValidSalesforceId(String idValue) {
        if (String.isBlank(idValue)) return false;
        if (idValue.length() != 15 && idValue.length() != 18) return false;
        Pattern idPattern = Pattern.compile('^[a-zA-Z0-9]+$');
        Matcher m = idPattern.matcher(idValue);
        return m.matches();
    }
    // Fetch just the list of active flow definitions
    public static List<Map<String, Object>> fetchFlowDefinitions(String sessionId) {
        String baseUrl    = URL.getOrgDomainUrl().toExternalForm();
        String apiVersion = '61.0';

        if (!baseUrl.containsIgnoreCase('.salesforce.com')
            && !baseUrl.containsIgnoreCase('.force.com')) {
            throw new FlowScannerException('Unexpected org domain: ' + baseUrl);
        }

        String soql = EncodingUtil.urlEncode(
            'SELECT Id, DeveloperName, MasterLabel, Description, ActiveVersionId '
            + 'FROM FlowDefinition WHERE ActiveVersionId != null', 'UTF-8'
        );

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/services/data/v' + apiVersion
                        + '/tooling/query?q=' + soql);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new FlowScannerException(
                'Tooling API query failed: ' + res.getStatus() + ' ' + res.getBody()
            );
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) responseMap.get('records');

        List<Map<String, Object>> definitions = new List<Map<String, Object>>();
        for (Object rec : records) {
            Map<String, Object> flowRec = (Map<String, Object>) rec;
            String activeVersionId = (String) flowRec.get('ActiveVersionId');
            String definitionId    = (String) flowRec.get('Id');
            if (String.isBlank(activeVersionId)) continue;
            if (!isValidSalesforceId(activeVersionId)) continue;
            if (!isValidSalesforceId(definitionId)) continue;
            definitions.add(flowRec);
        }
        return definitions;
    }

    // Fetch metadata for a single flow by version ID
    public static FlowWrapper fetchSingleFlow(
        Map<String, Object> flowRec, String sessionId
    ) {
        String baseUrl    = URL.getOrgDomainUrl().toExternalForm();
        String apiVersion = '61.0';

        String activeVersionId = (String) flowRec.get('ActiveVersionId');
        String definitionId    = (String) flowRec.get('Id');
        String developerName   = String.valueOf(flowRec.get('DeveloperName'));
        String masterLabel     = String.valueOf(flowRec.get('MasterLabel'));
        String description     = flowRec.get('Description') != null
            ? String.valueOf(flowRec.get('Description')) : null;

        return fetchFlowMetadata(
            baseUrl, apiVersion, activeVersionId,
            developerName, masterLabel, description,
            definitionId, sessionId
        );
    }

    public class FlowScannerException extends Exception {}
}