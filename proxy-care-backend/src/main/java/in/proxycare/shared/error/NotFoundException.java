package in.proxycare.shared.error;

/**
 * The resource does not exist, or the caller may not know it exists (ADR 0004: a resource another
 * user owns is reported as not found, never as forbidden).
 */
public class NotFoundException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public NotFoundException() {
    super(ErrorCode.NOT_FOUND);
  }

  public NotFoundException(String detail) {
    super(ErrorCode.NOT_FOUND, detail);
  }
}
