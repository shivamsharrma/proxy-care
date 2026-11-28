package com.proxycare.infrastructure.bank.razorpay.gateway;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.infrastructure.bank.gateway.IIfscDirectory;
import com.proxycare.infrastructure.bank.model.BankBranch;
import com.proxycare.infrastructure.bank.razorpay.config.RazorpayIfscProperties;
import com.proxycare.infrastructure.bank.razorpay.dto.response.RazorpayIfscResponse;
import com.proxycare.infrastructure.bank.razorpay.exception.RazorpayIfscException;
import com.proxycare.infrastructure.bank.razorpay.mapper.RazorpayIfscMapper;
import java.net.http.HttpClient;
import java.util.Optional;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/** The only class that calls Razorpay's IFSC directory. */
@Component
public class RazorpayIfscDirectory implements IIfscDirectory {

    public static final String CACHE_NAME = "ifsc-branches";
    private static final String BRANCH_PATH = "/{ifsc}";

    private final RestClient restClient;
    private final RazorpayIfscMapper razorpayIfscMapper;

    public RazorpayIfscDirectory(RazorpayIfscProperties razorpayIfscProperties, RazorpayIfscMapper razorpayIfscMapper) {
        this.restClient = buildRestClient(razorpayIfscProperties);
        this.razorpayIfscMapper = razorpayIfscMapper;
    }

    @Override
    @Cacheable(CACHE_NAME)
    public Optional<BankBranch> findByIfsc(String ifsc) {
        try {
            RazorpayIfscResponse razorpayIfscResponse = restClient.get()
                    .uri(BRANCH_PATH, ifsc)
                    .retrieve()
                    .body(RazorpayIfscResponse.class);
            return Optional.ofNullable(razorpayIfscResponse).map(razorpayIfscMapper::toBankBranch);
        } catch (HttpClientErrorException.NotFound notFoundException) {
            return Optional.empty();
        } catch (ResourceAccessException resourceAccessException) {
            throw new RazorpayIfscException(ErrorCode.EXTERNAL_SERVICE_UNAVAILABLE, resourceAccessException);
        } catch (RestClientException restClientException) {
            throw new RazorpayIfscException(ErrorCode.EXTERNAL_SERVICE_ERROR, restClientException);
        }
    }

    private static RestClient buildRestClient(RazorpayIfscProperties razorpayIfscProperties) {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(razorpayIfscProperties.connectTimeout())
                .build();
        JdkClientHttpRequestFactory jdkClientHttpRequestFactory = new JdkClientHttpRequestFactory(httpClient);
        jdkClientHttpRequestFactory.setReadTimeout(razorpayIfscProperties.readTimeout());
        return RestClient.builder()
                .baseUrl(razorpayIfscProperties.baseUrl())
                .requestFactory(jdkClientHttpRequestFactory)
                .build();
    }
}
