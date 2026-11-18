package in.proxycare.shared.error;

/** The update needs an If-Match header and none was sent (428). */
public class PreconditionRequiredException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public PreconditionRequiredException() {
    super(ErrorCode.PRECONDITION_REQUIRED);
  }
}
