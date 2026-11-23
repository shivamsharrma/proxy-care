package com.proxycare.features.user.mapper;

import com.proxycare.features.user.dto.response.AppUserResponse;
import com.proxycare.features.user.entity.AppUserEntity;
import org.springframework.stereotype.Component;

@Component
public class AppUserMapper {

    public AppUserResponse toAppUserResponse(AppUserEntity appUserEntity, String phone) {
        return new AppUserResponse(
                appUserEntity.getFullName(),
                appUserEntity.getSex(),
                appUserEntity.getAge(),
                appUserEntity.getAddress(),
                phone);
    }
}
