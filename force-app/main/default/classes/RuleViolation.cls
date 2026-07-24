public class RuleViolation {
    public String ruleName        { get; set; }
    public String severity        { get; set; }
    public String elementName     { get; set; }
    public String description     { get; set; }
    public String flowApiName     { get; set; }
    public String flowDefinitionId { get; set; }

    public RuleViolation(String ruleName, String severity, 
                         String elementName, String description) {
        this.ruleName    = ruleName;
        this.severity    = severity;
        this.elementName = elementName;
        this.description = description;
    }
}