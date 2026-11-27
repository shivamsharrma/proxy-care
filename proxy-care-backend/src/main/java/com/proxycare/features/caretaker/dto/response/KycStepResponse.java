package com.proxycare.features.caretaker.dto.response;

import com.proxycare.features.caretaker.enums.KycStep;
import com.proxycare.features.caretaker.enums.KycStepState;

public record KycStepResponse(KycStep step, KycStepState state) {}
