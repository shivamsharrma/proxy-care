package com.proxycare.infrastructure.payout.razorpayx.gateway;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.infrastructure.payout.exception.WebhookSignatureInvalidException;
import com.proxycare.infrastructure.payout.gateway.IBankVerificationService;
import com.proxycare.infrastructure.payout.model.BankVerification;
import com.proxycare.infrastructure.payout.model.BankVerificationCommand;
import com.proxycare.infrastructure.payout.razorpayx.config.RazorpayXProperties;
import com.proxycare.infrastructure.payout.razorpayx.dto.request.RazorpayXBankAccountRequest;
import com.proxycare.infrastructure.payout.razorpayx.dto.request.RazorpayXContactRequest;
import com.proxycare.infrastructure.payout.razorpayx.dto.request.RazorpayXFundAccountReference;
import com.proxycare.infrastructure.payout.razorpayx.dto.request.RazorpayXFundAccountRequest;
import com.proxycare.infrastructure.payout.razorpayx.dto.request.RazorpayXValidationRequest;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXContactResponse;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXFundAccountResponse;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXValidationCollectionResponse;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXValidationResponse;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXWebhookEvent;
import com.proxycare.infrastructure.payout.razorpayx.dto.response.RazorpayXWebhookPayloadEntry;
import com.proxycare.infrastructure.payout.razorpayx.exception.RazorpayXException;
import com.proxycare.infrastructure.payout.razorpayx.mapper.RazorpayXMapper;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

/**
 * The only class that calls RazorpayX. A validation has no idempotency key, so each one carries our attempt id in
 * {@code notes.bank_verification_request_id}, and {@link #findVerificationByRequestId} finds it again by listing.
 * Contacts and fund accounts are deduplicated by RazorpayX itself (same fields return the existing one).
 */
@Component
public class RazorpayXBankVerificationService implements IBankVerificationService {

    private static final String CONTACTS_PATH = "/v1/contacts";
    private static final String FUND_ACCOUNTS_PATH = "/v1/fund_accounts";
    private static final String VALIDATIONS_PATH = "/v1/fund_accounts/validations";
    private static final String VALIDATION_PATH = "/v1/fund_accounts/validations/{validationId}";
    private static final String VALIDATIONS_PAGE_PATH =
            "/v1/fund_accounts/validations?account_number={accountNumber}&count={count}&skip={skip}";
    private static final String CONTACT_NAME_PREFIX = "Caretaker ";
    private static final String ACCOUNT_TYPE_BANK_ACCOUNT = "bank_account";
    private static final long TEST_DEPOSIT_PAISE = 100L;
    private static final String CURRENCY_INR = "INR";
    private static final String REQUEST_ID_NOTE = "bank_verification_request_id";
    private static final int VALIDATIONS_PAGE_SIZE = 100;
    // A bound on the reconciliation scan, so a vendor that ignores skip can't loop forever.
    private static final int MAX_VALIDATION_PAGES = 100;
    private static final String VALIDATION_PAYLOAD_KEY = "fund_account.validation";
    private static final String HMAC_ALGORITHM = "HmacSHA256";

    private final RestClient restClient;
    private final RazorpayXProperties razorpayXProperties;
    private final RazorpayXMapper razorpayXMapper;
    private final JsonMapper jsonMapper;

    public RazorpayXBankVerificationService(
            RazorpayXProperties razorpayXProperties, RazorpayXMapper razorpayXMapper, JsonMapper jsonMapper) {
        this.restClient = buildRestClient(razorpayXProperties);
        this.razorpayXProperties = razorpayXProperties;
        this.razorpayXMapper = razorpayXMapper;
        this.jsonMapper = jsonMapper;
    }

    @Override
    public BankVerification requestVerification(BankVerificationCommand bankVerificationCommand) {
        RazorpayXContactResponse razorpayXContactResponse = post(
                CONTACTS_PATH, buildContactRequest(bankVerificationCommand.caretakerId()), RazorpayXContactResponse.class);
        RazorpayXFundAccountResponse razorpayXFundAccountResponse = post(
                FUND_ACCOUNTS_PATH,
                buildFundAccountRequest(razorpayXContactResponse.id(), bankVerificationCommand),
                RazorpayXFundAccountResponse.class);
        RazorpayXValidationResponse razorpayXValidationResponse = post(
                VALIDATIONS_PATH,
                buildValidationRequest(razorpayXFundAccountResponse.id(), bankVerificationCommand.verificationRequestId()),
                RazorpayXValidationResponse.class);
        if (razorpayXValidationResponse.id() == null) {
            throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_ERROR);
        }

        BankVerification bankVerification = razorpayXMapper.toBankVerification(razorpayXValidationResponse);
        return new BankVerification(
                razorpayXContactResponse.id(),
                razorpayXFundAccountResponse.id(),
                bankVerification.validationId(),
                bankVerification.validationStatus(),
                bankVerification.accountStatus(),
                bankVerification.registeredName(),
                bankVerification.nameMatchScore());
    }

    @Override
    public Optional<BankVerification> findVerificationByRequestId(UUID verificationRequestId) {
        for (int page = 0; page < MAX_VALIDATION_PAGES; page++) {
            List<RazorpayXValidationResponse> razorpayXValidationResponses = fetchValidationsPage(page);
            Optional<RazorpayXValidationResponse> matchingValidationResponse = razorpayXValidationResponses.stream()
                    .filter(razorpayXValidationResponse ->
                            isTaggedWith(razorpayXValidationResponse, verificationRequestId))
                    .findFirst();
            if (matchingValidationResponse.isPresent()) {
                return matchingValidationResponse.map(razorpayXMapper::toBankVerification);
            }
            if (razorpayXValidationResponses.size() < VALIDATIONS_PAGE_SIZE) {
                return Optional.empty();
            }
        }
        // Not knowing is not "not found": an empty answer here could send a second Rs 1.
        throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_ERROR);
    }

    @Override
    public BankVerification fetchVerification(String validationId) {
        RazorpayXValidationResponse razorpayXValidationResponse = callRazorpayX(() -> restClient.get()
                .uri(VALIDATION_PATH, validationId)
                .retrieve()
                .body(RazorpayXValidationResponse.class));
        if (razorpayXValidationResponse == null) {
            throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_ERROR);
        }
        return razorpayXMapper.toBankVerification(razorpayXValidationResponse);
    }

    @Override
    public Optional<BankVerification> parseWebhook(byte[] rawBody, String signature) {
        if (!hasValidSignature(rawBody, signature)) {
            throw new WebhookSignatureInvalidException();
        }

        RazorpayXWebhookEvent razorpayXWebhookEvent = readWebhookEvent(rawBody);
        Map<String, RazorpayXWebhookPayloadEntry> payload = razorpayXWebhookEvent.payload();
        RazorpayXWebhookPayloadEntry validationPayloadEntry = payload == null ? null : payload.get(VALIDATION_PAYLOAD_KEY);
        if (validationPayloadEntry == null || validationPayloadEntry.entity() == null) {
            return Optional.empty();
        }
        return Optional.of(razorpayXMapper.toBankVerification(validationPayloadEntry.entity()));
    }

    private List<RazorpayXValidationResponse> fetchValidationsPage(int page) {
        RazorpayXValidationCollectionResponse razorpayXValidationCollectionResponse = callRazorpayX(() -> restClient
                .get()
                .uri(VALIDATIONS_PAGE_PATH,
                        razorpayXProperties.accountNumber(), VALIDATIONS_PAGE_SIZE, page * VALIDATIONS_PAGE_SIZE)
                .retrieve()
                .body(RazorpayXValidationCollectionResponse.class));
        if (razorpayXValidationCollectionResponse == null || razorpayXValidationCollectionResponse.items() == null) {
            return List.of();
        }
        return razorpayXValidationCollectionResponse.items();
    }

    private <T> T post(String path, Object requestBody, Class<T> responseType) {
        T responseBody = callRazorpayX(() -> restClient.post()
                .uri(path)
                .contentType(MediaType.APPLICATION_JSON)
                .body(requestBody)
                .retrieve()
                .body(responseType));
        if (responseBody == null) {
            throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_ERROR);
        }
        return responseBody;
    }

    // The cause is dropped on purpose: Jackson's message quotes the body, which holds the registered name.
    private RazorpayXWebhookEvent readWebhookEvent(byte[] rawBody) {
        try {
            return jsonMapper.readValue(rawBody, RazorpayXWebhookEvent.class);
        } catch (JacksonException jacksonException) {
            throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_ERROR);
        }
    }

    // RazorpayX signs the raw body: hex HMAC-SHA256 with the webhook secret. Compared in constant time.
    private boolean hasValidSignature(byte[] rawBody, String signature) {
        if (signature == null || signature.isBlank()) {
            return false;
        }
        byte[] expectedSignature = HexFormat.of().formatHex(hmacSha256(rawBody)).getBytes(StandardCharsets.US_ASCII);
        byte[] receivedSignature = signature.trim().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.US_ASCII);
        return MessageDigest.isEqual(expectedSignature, receivedSignature);
    }

    private byte[] hmacSha256(byte[] rawBody) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(
                    razorpayXProperties.webhookSecret().getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM));
            return mac.doFinal(rawBody);
        } catch (GeneralSecurityException generalSecurityException) {
            throw new IllegalStateException(HMAC_ALGORITHM + " is not available", generalSecurityException);
        }
    }

    private static boolean isTaggedWith(RazorpayXValidationResponse razorpayXValidationResponse, UUID verificationRequestId) {
        return razorpayXValidationResponse.notes() instanceof Map<?, ?> notes
                && verificationRequestId.toString().equals(notes.get(REQUEST_ID_NOTE));
    }

    // Only our ids go into the contact: no name, phone or email of the caretaker (one contact per caretaker).
    private static RazorpayXContactRequest buildContactRequest(UUID caretakerId) {
        return new RazorpayXContactRequest(CONTACT_NAME_PREFIX + caretakerId, caretakerId.toString());
    }

    private static RazorpayXFundAccountRequest buildFundAccountRequest(
            String contactId, BankVerificationCommand bankVerificationCommand) {
        RazorpayXBankAccountRequest razorpayXBankAccountRequest = new RazorpayXBankAccountRequest(
                bankVerificationCommand.accountHolderName(),
                bankVerificationCommand.ifsc(),
                bankVerificationCommand.accountNumber());
        return new RazorpayXFundAccountRequest(contactId, ACCOUNT_TYPE_BANK_ACCOUNT, razorpayXBankAccountRequest);
    }

    private RazorpayXValidationRequest buildValidationRequest(String fundAccountId, UUID verificationRequestId) {
        return new RazorpayXValidationRequest(
                razorpayXProperties.accountNumber(),
                new RazorpayXFundAccountReference(fundAccountId),
                TEST_DEPOSIT_PAISE,
                CURRENCY_INR,
                Map.of(REQUEST_ID_NOTE, verificationRequestId.toString()));
    }

    private static <T> T callRazorpayX(Supplier<T> razorpayXCall) {
        try {
            return razorpayXCall.get();
        } catch (ResourceAccessException resourceAccessException) {
            throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_UNAVAILABLE, resourceAccessException);
        } catch (RestClientException restClientException) {
            throw new RazorpayXException(ErrorCode.EXTERNAL_SERVICE_ERROR, restClientException);
        }
    }

    private static RestClient buildRestClient(RazorpayXProperties razorpayXProperties) {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(razorpayXProperties.connectTimeout())
                .build();
        JdkClientHttpRequestFactory jdkClientHttpRequestFactory = new JdkClientHttpRequestFactory(httpClient);
        jdkClientHttpRequestFactory.setReadTimeout(razorpayXProperties.readTimeout());
        return RestClient.builder()
                .baseUrl(razorpayXProperties.baseUrl())
                .requestFactory(jdkClientHttpRequestFactory)
                .defaultHeaders(httpHeaders ->
                        httpHeaders.setBasicAuth(razorpayXProperties.keyId(), razorpayXProperties.keySecret()))
                .build();
    }
}
