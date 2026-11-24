package com.proxycare.features.patient.mapper;

import com.proxycare.features.patient.dto.response.PatientResponse;
import com.proxycare.features.patient.entity.PatientEntity;
import org.springframework.stereotype.Component;

@Component
public class PatientMapper {

    public PatientResponse toPatientResponse(PatientEntity patientEntity) {
        return new PatientResponse(
                patientEntity.getId(),
                patientEntity.getRelation(),
                patientEntity.getFullName(),
                patientEntity.getAge(),
                patientEntity.getSex(),
                patientEntity.getMobile(),
                patientEntity.isLivesAtUserAddress(),
                patientEntity.getAddress(),
                patientEntity.getMobility(),
                patientEntity.getHealthNotes());
    }
}
