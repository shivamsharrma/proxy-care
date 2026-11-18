package in.proxycare.shared.error;

/**
 * A partner service (payment gateway, ride partner, KYC) failed or answered unusably. The detail is
 * ours; the vendor response belongs in the cause, which is logged and never sent to clients.
 */
public class UpstreamException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public UpstreamException(String detail, Throwable cause) {
    super(ErrorCode.UPSTREAM_ERROR, detail, cause);
  }

  /** The partner did not answer in time (504). */
  public static UpstreamException timeout(String detail, Throwable cause) {
    return new UpstreamException(ErrorCode.UPSTREAM_TIMEOUT, detail, cause);
  }

  private UpstreamException(ErrorCode code, String detail, Throwable cause) {
    super(code, detail, cause);
  }
}
