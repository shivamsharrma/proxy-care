@onboarding @caretaker-app @screen-C1
Feature: Caretaker KYC checklist (Screen C1)
  As a Caretaker signing up
  I want a checklist of onboarding steps with their status
  So that I know what is done, what is next, and can resume any time

  # Source: proxy-care-api-context.md §5 "C1 KYC checklist" (resumable)
  # MVP RULE: C3 "Aadhaar & PAN" is NOT integrated in the MVP. C2 Basic information leads
  #           straight to C4 Photo & identity check. The Aadhaar & PAN step must not appear
  #           on the checklist and no scenario in this suite covers C3.
  # MVP checklist steps (4): Mobile number -> Basic information -> Photo & video KYC -> Payout account.
  # KYC status: IN_PROGRESS (step n of 4) -> SUBMITTED (video KYC scheduled) -> APPROVED / REJECTED.

  Background:
    Given I am signing up in the Caretaker app
    And I have verified the mobile number "9988776655"

  @smoke @happy-path
  Scenario: New caretaker sees the MVP checklist after OTP verification
    When I land on the "KYC checklist" screen
    Then I should see these steps in this order:
      | step                  | status |
      | Mobile number         | Done   |
      | Basic information     | Current|
      | Photo & video KYC     | To do  |
      | Payout account        | To do  |
    And I should see the progress "Step 2 of 4"

  @mvp-scope @IgnoreForMVP
  Scenario: Aadhaar & PAN step is hidden in the MVP build
    When I land on the "KYC checklist" screen
    Then no step labelled "Aadhaar & PAN" should be shown
    And the total step count should be 4

  @happy-path
  Scenario: Tapping the current step opens Basic information
    Given I am on the "KYC checklist" screen
    When I tap the "Basic information" step
    Then I should see the "Basic information" screen

  @happy-path
  Scenario: Primary action continues with the current step
    Given I am on the "KYC checklist" screen
    When I tap the primary "Continue" button
    Then I should see the "Basic information" screen

  @ui-state
  Scenario: Steps marked "To do" cannot be opened before earlier steps are done
    Given I am on the "KYC checklist" screen
    When I tap the "Payout account" step
    Then I should remain on the "KYC checklist" screen
    And the "Payout account" step should be shown as locked

  @happy-path
  Scenario Outline: Checklist reflects saved progress when resuming
    Given my onboarding progress is "<progress>"
    When I open the app
    Then I should see the "KYC checklist" screen
    And the step "<current>" should be marked "Current"
    And I should see the progress "<label>"

    Examples:
      | progress                        | current            | label       |
      | basic info saved partially      | Basic information  | Step 2 of 4 |
      | basic info completed            | Photo & video KYC  | Step 3 of 4 |
      | photo taken and call booked     | Payout account     | Step 4 of 4 |

  @happy-path
  Scenario: Completed steps show as Done
    Given I have completed "Basic information"
    When I am on the "KYC checklist" screen
    Then the "Basic information" step should be marked "Done"
    And the "Photo & video KYC" step should be marked "Current"

  @happy-path
  Scenario: A completed step can be reopened to review details
    Given I have completed "Basic information"
    And I am on the "KYC checklist" screen
    When I tap the "Basic information" step
    Then I should see the "Basic information" screen pre-filled with my saved details

  @navigation
  Scenario: Submitted caretaker is not shown the checklist
    Given my KYC status is "SUBMITTED"
    When I open the app
    Then I should see the "Under review" screen

  @navigation
  Scenario: Approved caretaker goes straight to Home
    Given my KYC status is "APPROVED"
    When I open the app
    Then I should see the "Home (P1)" screen

  @ui-state
  Scenario: Loading state while progress is fetched
    Given the KYC progress request is slow
    When I land on the "KYC checklist" screen
    Then I should see skeleton placeholders for the steps

  @negative
  Scenario: Progress fails to load
    Given the KYC progress request fails
    When I land on the "KYC checklist" screen
    Then I should see the error "Couldn't load your progress. Try again."
    And I should see a "Retry" button

  @navigation
  Scenario: Back on the checklist does not return to OTP verification
    Given I am on the "KYC checklist" screen
    When I press the back button
    Then I should not see the "Verify OTP" screen
    And the app should close or go to the background
