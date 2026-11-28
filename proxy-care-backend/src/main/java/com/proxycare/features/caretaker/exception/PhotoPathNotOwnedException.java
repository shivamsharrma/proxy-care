package com.proxycare.features.caretaker.exception;

import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.exception.ServiceInputException;

/** The reported photo path is outside the caller's own folder of the caretaker-photos bucket. */
public class PhotoPathNotOwnedException extends ServiceInputException {

    private static final String MESSAGE = "The photo must be uploaded to your own folder.";

    public PhotoPathNotOwnedException() {
        super(ErrorCode.PHOTO_PATH_NOT_OWNED, MESSAGE);
    }
}
