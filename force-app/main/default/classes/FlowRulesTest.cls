@isTest
private class FlowRulesTest {

    // ── NoFaultPathRule ──────────────────────────────────────────
    @isTest
    static void testNoFaultPathRule_Violation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name              = 'Create_Account';
        el.elementType       = 'RecordCreate';
        el.hasFaultConnector = false;
        flow.elements.add(el);

        NoFaultPathRule rule = new NoFaultPathRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 'Should flag missing fault path');
        System.assertEquals('Error', violations[0].severity);
    }

    @isTest
    static void testNoFaultPathRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name              = 'Create_Account';
        el.elementType       = 'RecordCreate';
        el.hasFaultConnector = true;
        flow.elements.add(el);

        NoFaultPathRule rule = new NoFaultPathRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag when fault path exists');
    }

    // ── DmlInLoopRule ────────────────────────────────────────────
    @isTest
    static void testDmlInLoopRule_Violation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name           = 'Create_In_Loop';
        el.elementType    = 'RecordCreate';
        el.parentLoopName = 'MyLoop';
        flow.elements.add(el);

        DmlInLoopRule rule = new DmlInLoopRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 'Should flag DML inside loop');
        System.assertEquals('Error', violations[0].severity);
    }

    @isTest
    static void testDmlInLoopRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Create_Outside';
        el.elementType = 'RecordCreate';
        // parentLoopName is null — not inside a loop
        flow.elements.add(el);

        DmlInLoopRule rule = new DmlInLoopRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag DML outside loop');
    }

    // ── MissingDescriptionRule ───────────────────────────────────
    @isTest
    static void testMissingDescriptionRule_Violation() {
        FlowWrapper flow    = makeFlow();
        flow.description    = null;

        MissingDescriptionRule rule = new MissingDescriptionRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 
            'Should flag missing description');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testMissingDescriptionRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        flow.description = 'This flow does something useful.';

        MissingDescriptionRule rule = new MissingDescriptionRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag when description exists');
    }

    // ── TooManyElementsRule ──────────────────────────────────────
    @isTest
    static void testTooManyElementsRule_Violation() {
        FlowWrapper flow = makeFlow();
        TooManyElementsRule.ELEMENT_THRESHOLD = 5; // lower for testing

        for (Integer i = 0; i < 6; i++) {
            FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
            el.name        = 'Element_' + i;
            el.elementType = 'Assignment';
            flow.elements.add(el);
        }

        TooManyElementsRule rule = new TooManyElementsRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 
            'Should flag too many elements');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testTooManyElementsRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        TooManyElementsRule.ELEMENT_THRESHOLD = 30;

        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Single_Element';
        el.elementType = 'Assignment';
        flow.elements.add(el);

        TooManyElementsRule rule = new TooManyElementsRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag under threshold');
    }

    // ── HardcodedIdRule ──────────────────────────────────────────
    @isTest
    static void testHardcodedIdRule_Violation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Assign_Hardcoded';
        el.elementType = 'Assignment';
        el.rawValue    = '{"value":"0013000000AbCde"}'; // 15-char Id with digits

        flow.elements.add(el);

        HardcodedIdRule rule = new HardcodedIdRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 
            'Should flag hardcoded Id');
        System.assertEquals('Error', violations[0].severity);
    }

    @isTest
    static void testHardcodedIdRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Clean_Element';
        el.elementType = 'Assignment';
        el.rawValue    = '{"value":"No hardcoded IDs here"}';
        flow.elements.add(el);

        HardcodedIdRule rule = new HardcodedIdRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag clean values');
    }

    // ── HardcodedUrlRule ─────────────────────────────────────────

    @isTest
    static void testHardcodedUrlRule_Violation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Set_Portal_URL';
        el.elementType = 'Assignment';
        el.rawValue    = '{"value":"https://portal.mycompany.com/onboard"}';
        flow.elements.add(el);

        HardcodedUrlRule rule = new HardcodedUrlRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 'Should flag hardcoded URL');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testHardcodedUrlRule_SafeDomain() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Salesforce_Ref';
        el.elementType = 'Assignment';
        el.rawValue    = '{"value":"https://login.salesforce.com/services/oauth2"}';
        flow.elements.add(el);

        HardcodedUrlRule rule = new HardcodedUrlRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag Salesforce system domain');
    }

    @isTest
    static void testHardcodedUrlRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Clean_Element';
        el.elementType = 'Assignment';
        el.rawValue    = '{"value":"No URLs here at all"}';
        flow.elements.add(el);

        HardcodedUrlRule rule = new HardcodedUrlRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag clean values');
    }

    @isTest
    static void testHardcodedUrlRule_BlankRawValue() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Empty_Element';
        el.elementType = 'Assignment';
        el.rawValue    = null;
        flow.elements.add(el);

        HardcodedUrlRule rule = new HardcodedUrlRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should handle null rawValue gracefully');
    }

    // ── SubflowFaultPathRule ─────────────────────────────────────

    @isTest
    static void testSubflowFaultPathRule_Deactivated_ReturnsNoViolations() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper sf = new FlowWrapper.FlowElementWrapper();
        sf.name              = 'Create_Contacts_Subflow';
        sf.elementType       = 'Subflow';
        sf.hasFaultConnector = false;
        flow.subflows.add(sf);

        SubflowFaultPathRule rule = new SubflowFaultPathRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(0, violations.size(),
            'Should return no violations as rule is deactivated for subflow components');
    }

    @isTest
    static void testSubflowFaultPathRule_NoSubflows() {
        FlowWrapper flow = makeFlow();
        // no subflows added

        SubflowFaultPathRule rule = new SubflowFaultPathRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should return empty when no subflows exist');
    }

    // ── NoTriggerConfigRule ──────────────────────────────────────

    @isTest
    static void testNoTriggerConfigRule_RecordTriggerMissingObject_Violation() {
        FlowWrapper flow    = makeFlow();
        flow.processType    = 'RecordTriggeredFlow';
        flow.startConfig    = null; // no start config

        NoTriggerConfigRule rule = new NoTriggerConfigRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(),
            'Should flag RecordTriggeredFlow with no object');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testNoTriggerConfigRule_RecordBeforeSaveMissingObject() {
        FlowWrapper flow    = makeFlow();
        flow.processType    = 'AutoLaunchedFlow';
        FlowWrapper.FlowStartWrapper start = new FlowWrapper.FlowStartWrapper();
        start.triggerType   = 'RecordBeforeSave';
        start.objectApiName = null; // missing object
        flow.startConfig    = start;

        NoTriggerConfigRule rule = new NoTriggerConfigRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(),
            'Should flag when record trigger type exists but object is blank');
    }

    @isTest
    static void testNoTriggerConfigRule_NoViolation() {
        FlowWrapper flow    = makeFlow();
        flow.processType    = 'AutoLaunchedFlow';
        FlowWrapper.FlowStartWrapper start = new FlowWrapper.FlowStartWrapper();
        start.triggerType   = 'RecordBeforeSave';
        start.objectApiName = 'Account';
        flow.startConfig    = start;

        NoTriggerConfigRule rule = new NoTriggerConfigRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag when trigger and object are configured');
    }

    @isTest
    static void testNoTriggerConfigRule_AutoLaunchedSubflow_NoViolation() {
        FlowWrapper flow    = makeFlow();
        flow.processType    = 'AutoLaunchedFlow';
        flow.startConfig    = null; // standard subflow has no startConfig / trigger

        NoTriggerConfigRule rule = new NoTriggerConfigRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag standard autolaunched subflows');
    }

    @isTest
    static void testNoTriggerConfigRule_ScreenFlow() {
        FlowWrapper flow = makeFlow();
        flow.processType = 'Flow'; // Screen flow — no trigger needed
        flow.startConfig = null;

        NoTriggerConfigRule rule = new NoTriggerConfigRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag screen flows');
    }

    // ── UnusedVariableRule ───────────────────────────────────────

    @isTest
    static void testUnusedVariableRule_Violation() {
        FlowWrapper flow = makeFlow();

        FlowWrapper.FlowVariableWrapper var1 = new FlowWrapper.FlowVariableWrapper();
        var1.name     = 'varUnused';
        var1.dataType = 'Text';
        var1.isInput  = false;
        var1.isOutput = false;
        flow.variables.add(var1);

        // Element that does NOT reference varUnused
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Create_Record';
        el.elementType = 'RecordCreate';
        el.rawValue    = '{"object":"Account","inputAssignments":[]}';
        flow.elements.add(el);

        UnusedVariableRule rule = new UnusedVariableRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(), 'Should flag unused variable');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testUnusedVariableRule_NoViolation_Referenced() {
        FlowWrapper flow = makeFlow();

        FlowWrapper.FlowVariableWrapper var1 = new FlowWrapper.FlowVariableWrapper();
        var1.name     = 'varAccountId';
        var1.dataType = 'Text';
        var1.isInput  = false;
        var1.isOutput = false;
        flow.variables.add(var1);

        // Element that DOES reference varAccountId
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Create_Record';
        el.elementType = 'RecordCreate';
        el.rawValue    = '{"inputAssignments":[{"field":"Id","value":{"elementReference":"varAccountId"}}]}';
        flow.elements.add(el);

        UnusedVariableRule rule = new UnusedVariableRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag variable that is referenced in an element');
    }

    @isTest
    static void testUnusedVariableRule_NoViolation_InputOutput() {
        FlowWrapper flow = makeFlow();

        FlowWrapper.FlowVariableWrapper var1 = new FlowWrapper.FlowVariableWrapper();
        var1.name     = 'varInputParam';
        var1.dataType = 'Text';
        var1.isInput  = true;  // input variable — skip
        var1.isOutput = false;
        flow.variables.add(var1);

        UnusedVariableRule rule = new UnusedVariableRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag input/output variables');
    }

    @isTest
    static void testUnusedVariableRule_NoVariables() {
        FlowWrapper flow = makeFlow();
        // no variables at all

        UnusedVariableRule rule = new UnusedVariableRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should return empty when flow has no variables');
    }

    // ── DuplicateDmlRule ─────────────────────────────────────────

    @isTest
    static void testDuplicateDmlRule_Violation() {
        FlowWrapper flow = makeFlow();

        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name        = 'Create_Task_1';
        el1.elementType = 'RecordCreate';
        el1.objectName  = 'Task';
        flow.elements.add(el1);

        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name        = 'Create_Task_2';
        el2.elementType = 'RecordCreate';
        el2.objectName  = 'Task';
        flow.elements.add(el2);

        DuplicateDmlRule rule = new DuplicateDmlRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(),
            'Should flag duplicate RecordCreate on same object');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testDuplicateDmlRule_NoViolation_DifferentObjects() {
        FlowWrapper flow = makeFlow();

        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name        = 'Create_Task';
        el1.elementType = 'RecordCreate';
        el1.objectName  = 'Task';
        flow.elements.add(el1);

        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name        = 'Create_Case';
        el2.elementType = 'RecordCreate';
        el2.objectName  = 'Case';
        flow.elements.add(el2);

        DuplicateDmlRule rule = new DuplicateDmlRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag DML on different objects');
    }

    @isTest
    static void testDuplicateDmlRule_NoViolation_InsideLoop() {
        FlowWrapper flow = makeFlow();

        // Both are inside loops — DmlInLoopRule covers these, not this rule
        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name           = 'Create_Task_1';
        el1.elementType    = 'RecordCreate';
        el1.objectName     = 'Task';
        el1.parentLoopName = 'MyLoop';
        flow.elements.add(el1);

        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name           = 'Create_Task_2';
        el2.elementType    = 'RecordCreate';
        el2.objectName     = 'Task';
        el2.parentLoopName = 'MyLoop';
        flow.elements.add(el2);

        DuplicateDmlRule rule = new DuplicateDmlRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should skip elements inside loops');
    }

    @isTest
    static void testDuplicateDmlRule_NoViolation_BlankObjectName() {
        FlowWrapper flow = makeFlow();

        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name        = 'Create_1';
        el1.elementType = 'RecordCreate';
        el1.objectName  = null; // blank — skip
        flow.elements.add(el1);

        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name        = 'Create_2';
        el2.elementType = 'RecordCreate';
        el2.objectName  = null;
        flow.elements.add(el2);

        DuplicateDmlRule rule = new DuplicateDmlRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should skip elements with no object name');
    }

    // ── UnconnectedElementRule ───────────────────────────────────

    @isTest
    static void testUnconnectedElementRule_Violation() {
        FlowWrapper flow = makeFlow();
        flow.connectedElements = new Set<String>{'Connected_Element'};

        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name        = 'Connected_Element';
        el1.elementType = 'RecordCreate';
        flow.elements.add(el1);

        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name        = 'Orphan_Element';
        el2.elementType = 'RecordCreate';
        flow.elements.add(el2);

        UnconnectedElementRule rule = new UnconnectedElementRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(),
            'Should flag element not reachable from Start');
        System.assertEquals('Orphan_Element', violations[0].elementName);
    }

    @isTest
    static void testUnconnectedElementRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        flow.connectedElements = new Set<String>{'El_One', 'El_Two'};

        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name        = 'El_One';
        el1.elementType = 'RecordCreate';
        flow.elements.add(el1);

        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name        = 'El_Two';
        el2.elementType = 'Assignment';
        flow.elements.add(el2);

        UnconnectedElementRule rule = new UnconnectedElementRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should not flag when all elements are connected');
    }

    @isTest
    static void testUnconnectedElementRule_UnconnectedSubflow() {
        FlowWrapper flow = makeFlow();
        flow.connectedElements = new Set<String>{'Connected_El'};

        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Connected_El';
        el.elementType = 'RecordCreate';
        flow.elements.add(el);

        // Subflow that is not connected
        FlowWrapper.FlowElementWrapper sf = new FlowWrapper.FlowElementWrapper();
        sf.name        = 'Orphan_Subflow';
        sf.elementType = 'Subflow';
        flow.subflows.add(sf);

        UnconnectedElementRule rule = new UnconnectedElementRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(),
            'Should flag unconnected subflow');
    }

    @isTest
    static void testUnconnectedElementRule_NullConnectedSet() {
        FlowWrapper flow = makeFlow();
        flow.connectedElements = null;

        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Some_Element';
        el.elementType = 'RecordCreate';
        flow.elements.add(el);

        UnconnectedElementRule rule = new UnconnectedElementRule();
        System.assertEquals(0, rule.evaluate(flow).size(),
            'Should handle null connectedElements gracefully');
    }

    // ── FlowWrapper coverage ─────────────────────────────────────

    @isTest
    static void testFlowWrapperInnerClasses() {
        FlowWrapper flow = new FlowWrapper();
        System.assertNotEquals(null, flow.elements, 'Elements list should init');
        System.assertNotEquals(null, flow.variables, 'Variables list should init');
        System.assertNotEquals(null, flow.subflows, 'Subflows list should init');
        System.assertNotEquals(null, flow.connectedElements, 'ConnectedElements set should init');

        FlowWrapper.FlowVariableWrapper v = new FlowWrapper.FlowVariableWrapper();
        v.name     = 'testVar';
        v.dataType = 'Text';
        v.isInput  = true;
        v.isOutput = false;
        System.assertEquals('testVar', v.name);

        FlowWrapper.FlowStartWrapper s = new FlowWrapper.FlowStartWrapper();
        s.triggerType       = 'RecordBeforeSave';
        s.objectApiName     = 'Account';
        s.recordTriggerType = 'Create';
        System.assertEquals('RecordBeforeSave', s.triggerType);
        System.assertEquals('Account', s.objectApiName);
    }
    // ── NoFaultPathRule — fault path exclusion ───────────────────

    @isTest
    static void testNoFaultPathRule_SkipsFaultPathElement() {
        FlowWrapper flow = makeFlow();

        // This element IS on a fault path — should NOT be flagged
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name              = 'Log_Error_Record';
        el.elementType       = 'RecordCreate';
        el.hasFaultConnector = false;
        el.isOnFaultPath     = true; // key flag
        flow.elements.add(el);

        NoFaultPathRule rule = new NoFaultPathRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(0, violations.size(),
            'Should not flag DML elements that are already on a fault path');
    }

    @isTest
    static void testNoFaultPathRule_FlagsDmlNotOnFaultPath() {
        FlowWrapper flow = makeFlow();

        // Normal DML — not on fault path, no fault connector — should be flagged
        FlowWrapper.FlowElementWrapper el1 = new FlowWrapper.FlowElementWrapper();
        el1.name              = 'Create_Account';
        el1.elementType       = 'RecordCreate';
        el1.hasFaultConnector = false;
        el1.isOnFaultPath     = false;
        flow.elements.add(el1);

        // This one IS on fault path — should NOT be flagged
        FlowWrapper.FlowElementWrapper el2 = new FlowWrapper.FlowElementWrapper();
        el2.name              = 'Log_Error';
        el2.elementType       = 'RecordCreate';
        el2.hasFaultConnector = false;
        el2.isOnFaultPath     = true;
        flow.elements.add(el2);

        NoFaultPathRule rule = new NoFaultPathRule();
        List<RuleViolation> violations = rule.evaluate(flow);
        System.assertEquals(1, violations.size(),
            'Should flag only the element not on fault path');
        System.assertEquals('Create_Account', violations[0].elementName,
            'Should flag Create_Account, not Log_Error');
    }

    @isTest
    static void testTooManyScreenFieldsRule_Violation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Big_Screen';
        el.elementType = 'Screen';
        el.fieldCount  = 12;
        flow.elements.add(el);

        TooManyScreenFieldsRule.FIELD_THRESHOLD = 10;
        List<RuleViolation> violations = new TooManyScreenFieldsRule().evaluate(flow);
        System.assertEquals(1, violations.size(), 'Should flag screen over threshold');
        System.assertEquals('Warning', violations[0].severity);
    }

    @isTest
    static void testTooManyScreenFieldsRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
        el.name        = 'Small_Screen';
        el.elementType = 'Screen';
        el.fieldCount  = 3;
        flow.elements.add(el);

        System.assertEquals(0, new TooManyScreenFieldsRule().evaluate(flow).size());
    }

    @isTest
    static void testRecursiveSubflowRule_Violation() {
        FlowWrapper flow = makeFlow(); // flowApiName = 'Test_Flow'
        FlowWrapper.FlowElementWrapper sf = new FlowWrapper.FlowElementWrapper();
        sf.name              = 'Call_Self';
        sf.elementType        = 'Subflow';
        sf.calledFlowApiName = 'Test_Flow';
        flow.subflows.add(sf);

        List<RuleViolation> violations = new RecursiveSubflowRule().evaluate(flow);
        System.assertEquals(1, violations.size(), 'Should flag self-recursive subflow');
        System.assertEquals('Error', violations[0].severity);
    }

    @isTest
    static void testRecursiveSubflowRule_NoViolation() {
        FlowWrapper flow = makeFlow();
        FlowWrapper.FlowElementWrapper sf = new FlowWrapper.FlowElementWrapper();
        sf.name              = 'Call_Other';
        sf.elementType        = 'Subflow';
        sf.calledFlowApiName = 'Some_Other_Flow';
        flow.subflows.add(sf);

        System.assertEquals(0, new RecursiveSubflowRule().evaluate(flow).size());
    }

    @isTest
    static void testTooManyElementsRule_NullLabel_UsesApiName() {
        FlowWrapper flow = makeFlow();
        flow.flowLabel = null;
        TooManyElementsRule.ELEMENT_THRESHOLD = 2;

        for (Integer i = 0; i < 3; i++) {
            FlowWrapper.FlowElementWrapper el = new FlowWrapper.FlowElementWrapper();
            el.name        = 'El_' + i;
            el.elementType = 'Assignment';
            flow.elements.add(el);
        }

        List<RuleViolation> violations = new TooManyElementsRule().evaluate(flow);
        System.assertEquals(1, violations.size());
        System.assert(!violations[0].description.contains('"null"'),
            'Should not contain string "null" in description. Actual: ' + violations[0].description);
        System.assert(violations[0].description.contains('Test_Flow'),
            'Should fall back to flowApiName');
    }

    @isTest
    static void testMissingDescriptionRule_NullLabel_UsesApiName() {
        FlowWrapper flow = makeFlow();
        flow.flowLabel = 'null';
        flow.description = null;

        List<RuleViolation> violations = new MissingDescriptionRule().evaluate(flow);
        System.assertEquals(1, violations.size());
        System.assert(!violations[0].description.contains('"null"'),
            'Should not contain string "null" in description');
        System.assert(violations[0].description.contains('Test_Flow'));
    }

    // ── Helper ───────────────────────────────────────────────────
    private static FlowWrapper makeFlow() {
        FlowWrapper flow    = new FlowWrapper();
        flow.flowApiName    = 'Test_Flow';
        flow.flowLabel      = 'Test Flow';
        flow.description    = 'A test flow';
        flow.processType    = 'AutoLaunchedFlow';
        return flow;
    }
}