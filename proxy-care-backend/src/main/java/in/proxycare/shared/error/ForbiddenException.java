package in.proxycare.shared.error;

/**
 * The authenticated caller may not perform this action (for example, the wrong role). For a
 * resource the caller may not see at all, use {@link NotFoundException} instead.
 */
public class ForbiddenException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public ForbiddenException() {
    super(ErrorCode.FORBIDDEN);
  }

  public ForbiddenException(String detail) {
    super(ErrorCode.FORBIDDEN, detail);
  }
}
