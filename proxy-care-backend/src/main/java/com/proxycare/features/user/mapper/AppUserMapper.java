package com.proxycare.features.user.mapper;

import com.proxycare.features.user.dto.request.SavePatientRequest;
import com.proxycare.features.user.dto.response.AppUserResponse;
import com.proxycare.features.user.dto.response.PatientResponse;
import com.proxycare.features.user.entity.AppUserEntity;
import com.proxycare.features.user.entity.PatientEntity;
import org.mapstruct.Mapper;

@Mapper
public interface AppUserMapper {

    AppUserResponse toAppUserResponse(AppUserEntity appUserEntity);

    PatientResponse toPatientResponse(PatientEntity patientEntity);

    PatientEntity toPatientEntity(SavePatientRequest savePatientRequest);
}
