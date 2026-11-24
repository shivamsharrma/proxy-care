package com.proxycare.features.patient.controller;

import com.proxycare.common.api.PageResponse;
import com.proxycare.features.patient.dto.request.SavePatientRequest;
import com.proxycare.features.patient.dto.response.PatientResponse;
import com.proxycare.features.patient.service.IPatientService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/patients")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER')")
public class PatientController {

    private final IPatientService patientService;

    @GetMapping
    public PageResponse<PatientResponse> listPatients(Pageable pageable) {
        return patientService.getCurrentUserPatients(pageable);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PatientResponse createPatient(@Valid @RequestBody SavePatientRequest savePatientRequest) {
        return patientService.createPatientForCurrentUser(savePatientRequest);
    }
}
