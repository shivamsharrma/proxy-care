@hospital @caretaker @H2 @H2a @H3 @H4
Feature: Caretaker scans a hospital bill QR, requests payment and attaches the bill (H2, H2a, H3, H4)
  As an assigned Caretaker at the hospital desk
  I want to scan the bill's UPI QR code, send a payment request and attach the hospital's bill once paid
  So that the family receives a verified request, keeps the bill on record and I never pay with my own money

  Rules (PRD 3.4, context §1, §2, §5):
    - QR checks: QR readable (UPI) · merchant name matches hospital · MCC is a hospital MCC (e.g. 8062).
    - Unreadable or non-UPI codes stay on H2; no hospital bill is created.
    - Merchant or MCC check fails -> bill status QR_MISMATCH on H3, no payment request is sent.
    - All checks pass -> H2a. Amount from the QR is read-only (amountSource QR); otherwise the caretaker types it (amountSource MANUAL).
    - Description is mandatory and is shown to the User.
    - "Send to family" creates the hospital bill (PAYMENT_REQUESTED) and a HOSPITAL_BILL payment request.
    - User pays -> PAID_BILL_PENDING; caretaker attaches the hospital's bill on H4 -> BILL_ATTACHED. User disputes -> DISPUTED.

  Background:
    Given I am logged in to the Caretaker app as an approved caretaker "Ramesh Kumar"
    And I am assigned to booking "PC-2481" in state "IN_PROGRESS"
    And the hospital for booking "PC-2481" is "Max Super Speciality Hospital, Saket"
    And the sponsoring user for booking "PC-2481" is "Anita Sharma"
    And I am on the "Services to-do" screen (H1)

  # ---------------------------------------------------------------------------
  # H2 Scan bill QR - camera
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Opening the scanner shows the camera viewfinder
    Given camera permission is granted
    When I tap the "Scan QR" card
    Then I should be on the "Scan bill QR" screen (H2)
    And I should see the camera viewfinder with a scan frame
    And I should see a "Torch" toggle

  Scenario: Toggling the torch
    Given I am on the "Scan bill QR" screen
    When I tap the "Torch" toggle
    Then the device torch should turn on
    And the "Torch" toggle should show the on state
    When I tap the "Torch" toggle
    Then the device torch should turn off

  @negative
  Scenario: Camera permission is requested on first use
    Given camera permission has not been requested yet
    When I tap the "Scan QR" card
    Then I should see the system camera permission prompt
    When I allow camera access
    Then I should see the camera viewfinder

  @negative
  Scenario: Camera permission denied
    Given camera permission is denied
    When I tap the "Scan QR" card
    Then I should see the message "Camera access is off"
    When I tap the "Scan QR" card
    Then I should see the system camera permission prompt

  Scenario: Device without torch hides the torch toggle
    Given the device has no flash
    When I open the "Scan bill QR" screen
    Then I should not see the "Torch" toggle

  @navigation
  Scenario: Back from the scanner returns to the services list
    Given I am on the "Scan bill QR" screen
    When I press the device back button
    Then I should be on the "Services to-do" screen (H1)
    And no hospital bill should be created for booking "PC-2481"

  # ---------------------------------------------------------------------------
  # Capture, H2a payment request details and sending
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Scanning a valid hospital QR with an amount sends a payment request to the family
    Given I am on the "Scan bill QR" screen
    And the bill QR encodes "upi://pay?pa=maxsaket@hdfcbank&pn=Max Super Speciality Hospital Saket&mc=8062&am=500.00"
    When I capture the QR code
    Then I should see a "Verifying bill" loader
    And I should be on the "Payment request details" screen (H2a)
    And I should see "QR verified · Max Super Speciality Hospital, Saket"
    And I should see the read-only "Amount in the QR" with "₹500"
    And I should not see an "Amount to request" field
    And the "Send to family" button should be disabled
    And no payment request should exist yet
    When I enter "OPD registration + consultation fee" in "What is this payment for?"
    And I tap "Send to family"
    Then I should be on the "Bill status" screen (H3)
    And I should see the amount "₹500"
    And I should see the description "OPD registration + consultation fee"
    And I should see the check "QR readable" as passed
    And I should see the check "Merchant name matches hospital" as passed
    And I should see the check "MCC is hospital (8062)" as passed
    And I should see the status banner "Payment requested from Anita"
    And a payment request of type "HOSPITAL_BILL" for "₹500" should exist with status "REQUESTED"
    And the payment request should show the description "OPD registration + consultation fee"
    And the payment request should not include a bill image
    And the hospital bill should have status "PAYMENT_REQUESTED"
    And the hospital bill should have amount source "QR"
    And the user "Anita Sharma" should receive a "Hospital payment request" notification

  @smoke
  Scenario: Scanning a valid hospital QR without an amount requires the caretaker to enter it
    Given I am on the "Scan bill QR" screen
    And the bill QR encodes "upi://pay?pa=maxsaket@hdfcbank&pn=Max Super Speciality Hospital Saket&mc=8062"
    When I capture the QR code
    Then I should see a "Verifying bill" loader
    And I should be on the "Payment request details" screen (H2a)
    And I should see an empty "Amount to request" field
    And I should see a note that the QR has no amount
    And the "Send to family" button should be disabled
    When I enter "650" in the "Amount to request" field
    And I enter "Lab test" in "What is this payment for?"
    Then the "Send to family" button should be enabled
    When I tap "Send to family"
    Then I should be on the "Bill status" screen (H3)
    And a payment request of type "HOSPITAL_BILL" for "₹650" should exist with status "REQUESTED"
    And the hospital bill should have amount source "MANUAL"

  Scenario Outline: Description quick chips fill the description
    Given I captured a valid hospital QR for "₹500"
    When I tap the quick chip "<chip>"
    Then the description should be "<chip>"
    And the "Send to family" button should be enabled

    Examples:
      | chip             |
      | Consultation fee |
      | Lab test         |
      | Medicines        |

  @navigation
  Scenario: Back from H2a creates nothing
    Given I captured a valid hospital QR for "₹500"
    When I press the device back button
    Then I should be on the "Scan bill QR" screen (H2)
    And no hospital bill should be created for booking "PC-2481"
    And no payment request should be created

  @negative
  Scenario: A double tap on Send to family creates one request
    Given I captured a valid hospital QR for "₹500"
    And I entered the description "OPD fee"
    When I double tap "Send to family"
    Then only one hospital bill should be created
    And only one "HOSPITAL_BILL" payment request should exist for that bill

  @negative
  Scenario: Sending the request fails
    Given I captured a valid hospital QR for "₹500"
    And I entered the description "OPD fee"
    And the send payment request call will fail
    When I tap "Send to family"
    Then I should see the error toast "Couldn't send the request. Try again."
    And I should remain on the "Payment request details" screen (H2a)
    And the description should still be "OPD fee"
    And no payment request should be created

  # ---------------------------------------------------------------------------
  # QR mismatch / validation
  # ---------------------------------------------------------------------------

  @negative
  Scenario Outline: A failed QR check blocks the payment request
    Given I am on the "Scan bill QR" screen
    And the bill QR has <condition>
    When I capture the QR code
    Then I should be on the "Bill status" screen (H3)
    And I should not have seen the "Payment request details" screen (H2a)
    And I should see the check "<failed_check>" as failed
    And I should see the status banner "QR mismatch: no request sent"
    And the hospital bill should have status "QR_MISMATCH"
    And no payment request should be created for the bill
    And the user should not receive any notification
    And I should see a "Scan again" button

    Examples:
      | condition                                                    | failed_check                   |
      | merchant name "Apollo Pharmacy Saket"                        | Merchant name matches hospital |
      | MCC "5912" (drug store)                                      | MCC is hospital                |
      | MCC "5411" (grocery)                                         | MCC is hospital                |
      | no MCC field                                                 | MCC is hospital                |
      | merchant name "Ramesh Kumar" and no MCC (personal UPI)       | Merchant name matches hospital |

  @negative
  Scenario Outline: Unreadable or non-UPI codes are rejected on the scanner
    Given I am on the "Scan bill QR" screen
    When I capture a code that is <code>
    Then I should see the error "<message>"
    And I should remain on the "Scan bill QR" screen
    And no hospital bill should be created

    Examples:
      | code                                   | message                                         |
      | a website URL "https://maxhealthcare.in" | This isn't a UPI payment QR. Scan the bill QR. |
      | a plain text code                      | This isn't a UPI payment QR. Scan the bill QR.  |
      | a barcode (EAN-13)                     | This isn't a UPI payment QR. Scan the bill QR.  |
      | blurred and unreadable                 | Couldn't read the QR. Hold steady and try again. |

  @negative
  Scenario Outline: Amount validation on the scanned QR
    Given I am on the "Scan bill QR" screen
    And the bill QR is from the hospital with amount "<amount>"
    When I capture the QR code
    Then <outcome>

    Examples:
      | amount  | outcome                                                                         |
      | 0.00    | I should see the error "Bill amount must be more than ₹0"                       |
      | -100.00 | I should see the error "Bill amount must be more than ₹0"                       |
      | abc     | I should see the error "Couldn't read the bill amount"                          |
      | 500.00  | I should see the read-only amount "₹500" on the "Payment request details" screen |
      | 1.00    | I should see the read-only amount "₹1" on the "Payment request details" screen   |

  @negative
  Scenario Outline: Amount to request validation when the QR has no amount
    Given I captured a valid hospital QR with no amount
    And I entered the description "OPD fee"
    When I enter "<amount>" in the "Amount to request" field
    Then <outcome>

    Examples:
      | amount | outcome                                                     |
      |        | the "Send to family" button should be disabled              |
      | 0      | I should see the inline error "Bill amount must be more than ₹0" |
      | 650    | the "Send to family" button should be enabled               |

  @negative
  Scenario Outline: Description field validation
    Given I captured a valid hospital QR for "₹500"
    When I enter "<description>" as the description
    Then <outcome>

    Examples:
      | description                       | outcome                                                                  |
      |                                   | the "Send to family" button should be disabled                           |
      | OPD fee                           | the "Send to family" button should be enabled                            |
      | [STRING_OF_201_CHARS]             | I should see the inline error "Keep the description under 200 characters" |

  @negative
  Scenario: Verification service fails
    Given I am on the "Scan bill QR" screen
    And the bill verification request will fail
    When I capture a valid hospital QR
    Then I should see the error toast "Couldn't verify the bill. Try again."
    And I should see a "Retry" action
    And no payment request should be created

  @negative
  Scenario: Same QR with an amount scanned twice creates only one request
    Given a hospital bill for "₹500" from a QR carrying that amount already has status "PAYMENT_REQUESTED"
    And I am on the "Scan bill QR" screen
    When I capture the same QR code again
    Then I should see the message "This bill was already sent to the family"
    And I should be on the "Bill status" screen for the existing bill
    And only one "HOSPITAL_BILL" payment request should exist for that QR payload

  Scenario: A desk QR without an amount can be used for a separate bill
    Given a hospital bill for "₹650" from a QR with no amount already has status "PAYMENT_REQUESTED"
    And I am on the "Scan bill QR" screen
    When I capture the same QR code again
    Then I should be on the "Payment request details" screen (H2a)
    When I enter "300" in the "Amount to request" field
    And I enter "Medicines" in "What is this payment for?"
    And I tap "Send to family"
    Then 2 "HOSPITAL_BILL" payment requests should exist for booking "PC-2481"

  # ---------------------------------------------------------------------------
  # H3 Bill status - realtime updates and actions
  # ---------------------------------------------------------------------------

  @smoke @realtime
  Scenario: Bill status asks for the hospital's bill when the family pays
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When the user "Anita Sharma" pays the hospital payment request
    Then I should see the alert "Anita paid ₹500"
    And the hospital bill should have status "PAID_BILL_PENDING"
    And I should see a card with "Take photo" and "Upload"
    And I should see the primary button "Attach hospital bill"
    And the "Remind family" button should not be visible

  @realtime
  Scenario: Bill status updates when the family disputes the bill
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When the user "Anita Sharma" marks the bill as "This bill looks wrong"
    Then the status banner should change to "Anita disputed this bill"
    And the hospital bill should have status "DISPUTED"
    And I should see the guidance "Check the bill with the desk and scan again if needed"
    And I should see a "Scan again" button

  @realtime
  Scenario: A failed payment attempt keeps the request open
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When the user's gateway payment for the bill fails
    Then the status banner should still show "Payment requested from Anita"
    And the "Remind family" button should be visible

  Scenario Outline: Actions available per bill status
    Given I am on the "Bill status" screen for a bill with status "<status>"
    Then I should see the buttons "<visible>"
    And I should not see the buttons "<hidden>"

    Examples:
      | status            | visible                                | hidden                                                 |
      | PAYMENT_REQUESTED | Back to services, Remind family        | Attach hospital bill, View hospital bill, Scan again   |
      | PAID_BILL_PENDING | Back to services, Attach hospital bill | Remind family, View hospital bill, Scan again          |
      | BILL_ATTACHED     | Back to services, View hospital bill   | Remind family, Attach hospital bill, Scan again        |
      | QR_MISMATCH       | Back to services, Scan again           | Remind family, Attach hospital bill, View hospital bill |
      | DISPUTED          | Back to services, Scan again           | Remind family, Attach hospital bill, View hospital bill |

  Scenario: Reminding the family about an unpaid bill
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When I tap "Remind family"
    Then I should see the toast "Reminder sent to Anita"
    And the user "Anita Sharma" should receive a reminder notification for the "₹500" bill
    And the "Remind family" button should be disabled for 2 minutes

  @negative
  Scenario: Remind family is rate limited
    Given I sent a reminder for the "₹500" bill less than 2 minutes ago
    When I open the "Bill status" screen for that bill
    Then the "Remind family" button should be disabled
    And I should see the hint "You can remind again in a moment"

  @navigation
  Scenario: Scan again from a mismatched bill opens the scanner
    Given I am on the "Bill status" screen for a bill with status "QR_MISMATCH"
    When I tap "Scan again"
    Then I should be on the "Scan bill QR" screen (H2)

  @navigation
  Scenario: Back to services returns to H1 and shows the bill on the Scan QR card
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When I tap "Back to services"
    Then I should be on the "Services to-do" screen (H1)
    And the "Scan QR" card should list the bill "₹500" with status "Payment requested"

  Scenario: Services can continue while a bill is unpaid
    Given a "₹500" hospital bill has status "PAYMENT_REQUESTED"
    And I am on the "Services to-do" screen
    Then the "Start" buttons on pending services should be enabled

  # Decided (22 Nov 2026): a PAID_BILL_PENDING bill does not block Leave hospital; it blocks
  # Visit Completed (05_hospital_access_control.feature, "Final bill gate on Visit Completed").
  Scenario: Leaving the hospital is allowed with an unpaid bill, but earnings go on hold later
    Given a "₹500" hospital bill has status "PAYMENT_REQUESTED"
    And every service on booking "PC-2481" has status "COMPLETED"
    When I open the "Services to-do" screen
    Then the "Leave hospital" button should be enabled
    And I should see the warning "1 bill still unpaid by family"

  Scenario: Caretaker never sees a pay option
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    Then I should not see any "Pay" button
    And I should see the note "Your family pays the hospital. Don't pay from your own money."

  # ---------------------------------------------------------------------------
  # H4 Attach hospital bill
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Attaching the hospital's bill after the family pays
    Given a "₹500" hospital bill with description "OPD registration + consultation fee" has status "PAID_BILL_PENDING"
    And I am on the "Bill status" screen for that bill
    When I tap "Attach hospital bill"
    Then I should be on the "Attach hospital bill" screen (H4)
    And I should see the description "OPD registration + consultation fee"
    And I should see the amount "₹500"
    And I should see "Paid by Anita" with the payment time
    And I should see the guidance "hospital name, date and amount must be readable"
    And the "Attach & share with Anita" button should be disabled
    When I take a photo of the bill
    Then I should see a preview of the photo with "Retake" and "Replace"
    And the "Attach & share with Anita" button should be enabled
    When I tap "Attach & share with Anita"
    Then I should be on the "Bill status" screen (H3)
    And I should see the status banner "Hospital bill attached · shared with Anita"
    And I should see a "View hospital bill" button
    And the hospital bill should have status "BILL_ATTACHED"
    And the final bill should record the file, its type, its size, the uploader and the upload time
    And the user "Anita Sharma" should receive a "Hospital bill attached" event

  Scenario: Attaching the hospital's bill as a PDF
    Given I am on the "Attach hospital bill" screen (H4) for a paid "₹500" bill
    When I upload the PDF "max-opd-bill.pdf"
    Then I should see a preview of "max-opd-bill.pdf" with "Replace"
    When I tap "Attach & share with Anita"
    Then the hospital bill should have status "BILL_ATTACHED"
    And the final bill should have type "PDF"

  Scenario: Replacing the chosen file before attaching
    Given I am on the "Attach hospital bill" screen (H4) for a paid "₹500" bill
    And I took a photo of the bill
    When I tap "Replace"
    And I upload the PDF "max-opd-bill.pdf"
    And I tap "Attach & share with Anita"
    Then the final bill should have type "PDF"
    And the final bill should have file name "max-opd-bill.pdf"

  # The maximum file size and allowed types for H4 are open (context §9), so no limit is specified here.
  @ui-state @negative
  Scenario: A file that is too large is rejected
    Given I am on the "Attach hospital bill" screen (H4) for a paid "₹500" bill
    When I upload a file above the allowed size
    Then I should see a file-too-large error
    And the "Attach & share with Anita" button should be disabled
    And the hospital bill should still have status "PAID_BILL_PENDING"

  @ui-state @negative
  Scenario: Upload progress and failure
    Given I am on the "Attach hospital bill" screen (H4) for a paid "₹500" bill
    And I took a photo of the bill
    And the bill upload will fail
    When I tap "Attach & share with Anita"
    Then I should see upload progress
    And I should see an upload failure with a retry option
    And I should remain on the "Attach hospital bill" screen (H4)
    And the hospital bill should still have status "PAID_BILL_PENDING"
    And the user "Anita Sharma" should not receive a "Hospital bill attached" event

  @navigation
  Scenario: Leaving H4 without a file keeps the bill pending
    Given I am on the "Attach hospital bill" screen (H4) for a paid "₹500" bill
    When I press the device back button
    Then I should be on the "Bill status" screen (H3)
    And the hospital bill should still have status "PAID_BILL_PENDING"
    And I should see the primary button "Attach hospital bill"

  @navigation
  Scenario: Viewing the attached hospital bill
    Given I am on the "Bill status" screen for a "₹500" bill with status "BILL_ATTACHED"
    When I tap "View hospital bill"
    Then I should see the attached hospital bill
