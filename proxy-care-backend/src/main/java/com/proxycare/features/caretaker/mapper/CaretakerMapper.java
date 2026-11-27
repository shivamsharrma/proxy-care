package com.proxycare.features.caretaker.mapper;

import com.proxycare.features.caretaker.dto.response.KycProgressResponse;
import com.proxycare.features.caretaker.dto.response.KycStepResponse;
import com.proxycare.features.caretaker.entity.CaretakerEntity;
import java.util.List;
import org.mapstruct.Mapper;

@Mapper
public interface CaretakerMapper {

    KycProgressResponse toKycProgressResponse(
            CaretakerEntity caretakerEntity, int stepNumber, int totalSteps, List<KycStepResponse> steps);
}
