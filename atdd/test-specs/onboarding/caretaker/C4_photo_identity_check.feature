@onboarding @caretaker-app @screen-C4 @mvp-scope
Feature: Caretaker photo and identity check (Screen C4)
  As a Caretaker who has completed basic information
  I want to take a profile photo and book a video KYC call
  So that Proxy Care can confirm my identity

  # Source: proxy-care-api-context.md §5 "C4 Photo & identity check"; design system (photo 96x120 portrait)
  # Inputs: profile photo* (camera only), video KYC slot* (time chips). Action: Book call -> C5.
  # MVP RULE: this screen is reached directly from C2 Basic information. C3 Aadhaar & PAN is not
  #           in the MVP and is not covered here.
  # DECISION: the MVP does not run video KYC. The slot the caretaker picks is stored as is, with no
  #           capacity or availability check; an admin calls the caretaker through another channel.
  #           Scenarios about full, missing or taken slots are tagged @IgnoreForMVP.
  # ASSUMPTION: slot list comes from the server; copy is placeholder.

  Background:
    Given I am a caretaker who has completed basic information
    And I am on the "Photo & identity check" screen

  @ui-state
  Scenario: Screen shows the photo placeholder and video KYC slots
    Then I should see a dashed portrait placeholder for the profile photo
    And I should see the "Take photo" action
    And I should see the photo guidance for an upper-body portrait
    And I should see available video KYC time slots as chips
    And the "Book call" button should be disabled

  @mvp-scope
  Scenario: The screen is reached directly after basic information
    Given I am on the "Basic information" screen with valid data
    When I tap "Save and continue"
    Then I should see the "Photo & identity check" screen
    And the step progress should show "Step 3 of 4"

  @smoke @happy-path
  Scenario: Taking a photo and booking a video KYC slot
    Given camera permission is granted
    When I tap "Take photo"
    And I capture a photo with the camera
    And I confirm the photo
    Then I should see my photo in the portrait frame
    When I select the video KYC slot "Tomorrow, 11:00 AM"
    And I tap "Book call"
    Then my profile photo should be uploaded
    And a video KYC call should be booked for "Tomorrow, 11:00 AM"
    And I should see the "Payout account" screen

  @mvp-scope
  Scenario: Photo can only be taken with the camera
    When I tap "Take photo"
    Then the camera should open
    And there should be no option to pick a photo from the gallery

  @happy-path
  Scenario: Retaking the photo before confirming
    Given camera permission is granted
    And I have captured a photo
    When I tap "Retake"
    Then the camera should open again
    And the previous capture should be discarded

  @happy-path
  Scenario: Replacing a confirmed photo
    Given I have confirmed a profile photo
    When I tap "Retake photo"
    And I capture and confirm a new photo
    Then the new photo should be shown in the portrait frame

  @ui-state
  Scenario Outline: Book call is enabled only when both photo and slot are provided
    Given the photo state is "<photo>"
    And the slot state is "<slot>"
    Then the "Book call" button should be "<button>"

    Examples:
      | photo     | slot         | button   |
      | missing   | not selected | disabled |
      | taken     | not selected | disabled |
      | missing   | selected     | disabled |
      | taken     | selected     | enabled  |

  @ui-state
  Scenario: Disabled Book call explains what is missing
    Given I have taken a photo
    And no video KYC slot is selected
    Then I should see a caption under "Book call" saying "Choose a time for your video call"

  @ui-state
  Scenario: Only one video KYC slot can be selected
    When I select the video KYC slot "Tomorrow, 11:00 AM"
    And I select the video KYC slot "Tomorrow, 3:00 PM"
    Then only "Tomorrow, 3:00 PM" should be selected

  @ui-state @IgnoreForMVP
  Scenario: Slots that are full are shown as unavailable
    Given the slot "Tomorrow, 10:00 AM" is fully booked
    Then the "Tomorrow, 10:00 AM" chip should be shown as unavailable
    And I should not be able to select it

  @ui-state @IgnoreForMVP
  Scenario: No slots available
    Given there are no video KYC slots available
    Then I should see the empty state "No call slots right now. Please check again later."
    And the "Book call" button should be disabled

  @negative
  Scenario: Camera permission denied
    Given camera permission is denied
    When I tap "Take photo"
    Then I should see the message "Allow camera access to take your photo"
    And I should see an "Open settings" action

  @negative
  Scenario: Camera permission permanently denied opens system settings
    Given camera permission is permanently denied
    When I tap "Open settings"
    Then the app settings page of the device should open

  @negative
  Scenario: Cancelling the camera keeps the placeholder
    When I tap "Take photo"
    And I close the camera without capturing
    Then I should see the dashed portrait placeholder
    And the "Book call" button should be disabled

  @negative
  Scenario: Photo upload fails
    Given I have taken a photo and selected a slot
    And the photo upload fails
    When I tap "Book call"
    Then I should see the error "Photo upload failed. Please try again."
    And my photo and slot selection should be kept
    And I should remain on the "Photo & identity check" screen

  @ui-state
  Scenario: Upload progress is shown while booking
    Given I have taken a photo and selected a slot
    When I tap "Book call"
    Then I should see upload progress for the photo
    And the "Book call" button should be disabled until the request finishes

  @negative @IgnoreForMVP
  Scenario: Selected slot gets taken by someone else before booking
    Given I have taken a photo
    And I have selected the slot "Tomorrow, 11:00 AM"
    And that slot becomes fully booked
    When I tap "Book call"
    Then I should see the error "That time was just taken. Please choose another."
    And the slot list should refresh
    And no slot should be selected

  @negative
  Scenario: Slots fail to load
    Given the video KYC slots request fails
    When the "Photo & identity check" screen loads
    Then I should see the error "Couldn't load call times. Try again."
    And I should see a "Retry" button in the slots section

  @edge-case
  Scenario: Tapping Book call twice books only one call
    Given I have taken a photo and selected a slot
    When I tap "Book call" twice quickly
    Then exactly one video KYC booking should be created

  @navigation
  Scenario: Back from Photo & identity check returns to the checklist
    When I press the back button
    Then I should see the "KYC checklist" screen
    And the "Photo & video KYC" step should be marked "Current"

  @navigation
  Scenario: Resuming after the app is closed keeps the progress
    Given I have completed basic information
    And I have not booked a call
    When I close and relaunch the app
    Then I should see the "KYC checklist" screen
    And the "Photo & video KYC" step should be marked "Current"
