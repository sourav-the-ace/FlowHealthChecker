public class FlowWrapper {
    public String flowApiName      { get; set; }
    public String flowLabel        { get; set; }
    public String description      { get; set; }
    public String processType      { get; set; }
    public String flowDefinitionId { get; set; }

    // Existing
    public List<FlowElementWrapper> elements { get; set; }

    // Phase 2 additions
    public List<FlowVariableWrapper>  variables   { get; set; }
    public List<FlowElementWrapper>   subflows    { get; set; }
    public Set<String>                connectedElements { get; set; }
    public FlowStartWrapper           startConfig { get; set; }

    public FlowWrapper() {
        this.elements          = new List<FlowElementWrapper>();
        this.variables         = new List<FlowVariableWrapper>();
        this.subflows          = new List<FlowElementWrapper>();
        this.connectedElements = new Set<String>();
    }

    public class FlowElementWrapper {
        public String  name              { get; set; }
        public String  elementType       { get; set; }
        public String  elementSubtype    { get; set; }
        public Boolean hasFaultConnector { get; set; }
        public String  parentLoopName    { get; set; }
        public Boolean isOnFaultPath     { get; set; }
        public String  rawValue          { get; set; }
        public String  objectName        { get; set; } // for Duplicate DML rule

        public FlowElementWrapper() {
            this.hasFaultConnector = false;
            this.isOnFaultPath     = false;
        }
    }

    public class FlowVariableWrapper {
        public String  name       { get; set; }
        public String  dataType   { get; set; }
        public Boolean isInput    { get; set; }
        public Boolean isOutput   { get; set; }
    }

    public class FlowStartWrapper {
        public String triggerType   { get; set; } // RecordBeforeSave, Scheduled, etc.
        public String objectApiName { get; set; }
        public String recordTriggerType { get; set; }
    }
}