package in.proxycare.shared.error;

/** The request conflicts with the current state, for example a duplicate or a concurrent change. */
public class ConflictException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public ConflictException() {
    super(ErrorCode.CONFLICT);
  }

  public ConflictException(String detail) {
    super(ErrorCode.CONFLICT, detail);
  }
}
