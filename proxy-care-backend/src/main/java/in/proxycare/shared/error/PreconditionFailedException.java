package in.proxycare.shared.error;

/** The If-Match version no longer matches the resource (412). */
public class PreconditionFailedException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public PreconditionFailedException() {
    super(ErrorCode.PRECONDITION_FAILED);
  }
}
