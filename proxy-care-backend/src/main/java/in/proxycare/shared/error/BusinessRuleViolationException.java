package in.proxycare.shared.error;

/**
 * A domain rule refused an otherwise valid request, for example cancelling a completed visit. The
 * detail says which rule, in terms a developer understands.
 */
public class BusinessRuleViolationException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public BusinessRuleViolationException(String detail) {
    super(ErrorCode.BUSINESS_RULE_VIOLATION, detail);
  }
}
