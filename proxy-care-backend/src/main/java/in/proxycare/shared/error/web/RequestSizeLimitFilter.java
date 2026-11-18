package in.proxycare.shared.error.web;

import in.proxycare.shared.error.ErrorCode;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Limits request bodies (ADR 0012: 1 MB). A declared {@code Content-Length} over the limit is
 * refused before anything reads the body. A chunked body is counted while it is read; crossing the
 * limit fails the read, which the exception handler reports as the same 413.
 */
public class RequestSizeLimitFilter extends OncePerRequestFilter {

  private final long maxBytes;
  private final ProblemResponseWriter writer;

  public RequestSizeLimitFilter(long maxBytes, ProblemResponseWriter writer) {
    if (maxBytes <= 0) {
      throw new IllegalArgumentException("maxBytes must be positive");
    }
    this.maxBytes = maxBytes;
    this.writer = writer;
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {
    if (request.getContentLengthLong() > maxBytes) {
      writer.write(request, response, ErrorCode.PAYLOAD_TOO_LARGE);
      return;
    }
    chain.doFilter(new LimitedRequest(request, maxBytes), response);
  }

  /** Whether {@code failure} was caused by a body that crossed the limit while being read. */
  public static boolean isTooLarge(Throwable failure) {
    for (Throwable cause = failure; cause != null; cause = cause.getCause()) {
      if (cause instanceof BodyTooLargeException) {
        return true;
      }
    }
    return false;
  }

  /** Thrown while reading a body that exceeds the limit. */
  static final class BodyTooLargeException extends IOException {

    private static final long serialVersionUID = 1L;

    BodyTooLargeException(long maxBytes) {
      super("Request body exceeds " + maxBytes + " bytes");
    }
  }

  private static final class LimitedRequest extends HttpServletRequestWrapper {

    private final long maxBytes;
    private ServletInputStream stream;

    LimitedRequest(HttpServletRequest request, long maxBytes) {
      super(request);
      this.maxBytes = maxBytes;
    }

    @Override
    public ServletInputStream getInputStream() throws IOException {
      if (stream == null) {
        stream = new LimitedInputStream(super.getInputStream(), maxBytes);
      }
      return stream;
    }

    @Override
    public BufferedReader getReader() throws IOException {
      String encoding = getCharacterEncoding();
      Charset charset = encoding == null ? StandardCharsets.UTF_8 : Charset.forName(encoding);
      return new BufferedReader(new InputStreamReader(getInputStream(), charset));
    }
  }

  /** Counts bytes read and fails once more than {@code maxBytes} have been read. */
  static final class LimitedInputStream extends ServletInputStream {

    private final ServletInputStream delegate;
    private final long maxBytes;
    private long count;

    LimitedInputStream(ServletInputStream delegate, long maxBytes) {
      this.delegate = delegate;
      this.maxBytes = maxBytes;
    }

    @Override
    public int read() throws IOException {
      int value = delegate.read();
      if (value >= 0) {
        count(1);
      }
      return value;
    }

    @Override
    public int read(byte[] buffer, int offset, int length) throws IOException {
      int read = delegate.read(buffer, offset, length);
      if (read > 0) {
        count(read);
      }
      return read;
    }

    private void count(int bytes) throws BodyTooLargeException {
      count += bytes;
      if (count > maxBytes) {
        throw new BodyTooLargeException(maxBytes);
      }
    }

    @Override
    public boolean isFinished() {
      return delegate.isFinished();
    }

    @Override
    public boolean isReady() {
      return delegate.isReady();
    }

    @Override
    public void setReadListener(ReadListener listener) {
      delegate.setReadListener(listener);
    }
  }
}
