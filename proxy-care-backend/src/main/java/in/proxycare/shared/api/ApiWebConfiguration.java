package in.proxycare.shared.api;

import in.proxycare.shared.error.web.ProblemResponseWriter;
import in.proxycare.shared.error.web.RequestSizeLimitFilter;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.HandlerTypePredicate;
import org.springframework.web.servlet.config.annotation.PathMatchConfigurer;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** API-wide web settings (ADR 0012). */
@Configuration(proxyBeanMethods = false)
class ApiWebConfiguration implements WebMvcConfigurer {

  /**
   * Every {@code @RestController} of the application is served under {@value ApiPaths#V1};
   * controllers declare only their resource path. Framework endpoints (actuator, API docs, the
   * error page) are not affected.
   */
  @Override
  public void configurePathMatch(PathMatchConfigurer configurer) {
    configurer.addPathPrefix(
        ApiPaths.V1,
        HandlerTypePredicate.forBasePackage("in.proxycare")
            .and(HandlerTypePredicate.forAnnotation(RestController.class)));
  }

  /** After the observation filter (so errors carry a trace id), before security and MVC. */
  @Bean
  FilterRegistrationBean<RequestSizeLimitFilter> requestSizeLimitFilter(
      ApiProperties properties, ProblemResponseWriter writer) {
    FilterRegistrationBean<RequestSizeLimitFilter> registration =
        new FilterRegistrationBean<>(
            new RequestSizeLimitFilter(properties.maxRequestBodySize().toBytes(), writer));
    registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 10);
    return registration;
  }
}
