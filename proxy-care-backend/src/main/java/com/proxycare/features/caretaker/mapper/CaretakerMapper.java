package com.proxycare.features.caretaker.mapper;

import com.proxycare.features.caretaker.dto.request.SaveBasicInformationRequest;
import com.proxycare.features.caretaker.dto.response.BasicInformationDraftResponse;
import com.proxycare.features.caretaker.dto.response.CaretakerResponse;
import com.proxycare.features.caretaker.dto.response.KycProgressResponse;
import com.proxycare.features.caretaker.dto.response.KycStepResponse;
import com.proxycare.features.caretaker.dto.response.PayoutAccountResponse;
import com.proxycare.features.caretaker.entity.BankVerificationRequestEntity;
import com.proxycare.features.caretaker.entity.BasicInformationDraft;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import com.proxycare.features.caretaker.enums.BankVerificationFailureReason;
import java.util.List;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper
public interface CaretakerMapper {

    KycProgressResponse toKycProgressResponse(
            CaretakerEntity caretakerEntity,
            int stepNumber,
            int totalSteps,
            List<KycStepResponse> steps,
            BankVerificationFailureReason bankFailureReason);

    CaretakerResponse toCaretakerResponse(CaretakerEntity caretakerEntity);

    BasicInformationDraft toBasicInformationDraft(SaveBasicInformationRequest saveBasicInformationRequest);

    BasicInformationDraftResponse toBasicInformationDraftResponse(BasicInformationDraft basicInformationDraft);

    @Mapping(target = "branch", source = "bankBranch")
    PayoutAccountResponse toPayoutAccountResponse(BankVerificationRequestEntity bankVerificationRequestEntity);
}
