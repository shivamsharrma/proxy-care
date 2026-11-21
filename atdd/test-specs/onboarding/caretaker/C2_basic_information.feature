@onboarding @caretaker-app @screen-C2
Feature: Caretaker basic information (Screen C2)
  As a Caretaker signing up
  I want to give my personal and contact details
  So that Proxy Care can vet me and families can trust me

  # Source: proxy-care-api-context.md §5 "C2 Basic information"; PRD §2.1
  # Inputs: full name (as on Aadhaar)*, sex*, age* (>=18), email*, emergency contact*,
  #         residential address*, occupation (optional), marital status (Single/Married, optional).
  # Actions: Save and continue; Save and finish later -> C1.
  # MVP RULE: "Save and continue" goes to C4 Photo & identity check (C3 Aadhaar & PAN is skipped).
  # ASSUMPTION: age treated as required because it must be >=18; upper bound 70 is a placeholder.
  # ASSUMPTION: emergency contact must differ from the caretaker's own mobile; copy is placeholder.

  Background:
    Given I am a caretaker with a verified mobile "9988776655"
    And I am on the "Basic information" screen

  @ui-state
  Scenario: Basic information form shows all fields
    Then I should see the field "Full name (as on Aadhaar)" marked as required
    And I should see the sex options "Female", "Male" and "Other" marked as required
    And I should see the field "Age" marked as required
    And I should see the field "Email" marked as required
    And I should see the field "Emergency contact" marked as required
    And I should see the field "Residential address" marked as required
    And I should see the optional field "Occupation"
    And I should see the optional marital status options "Single" and "Married"
    And I should see the primary button "Save and continue"
    And I should see the text button "Save and finish later"

  @ui-state
  Scenario: Inputs open the right keyboard
    Then the "Age" input should open the numeric keypad
    And the "Emergency contact" input should open the phone keypad
    And the "Email" input should open the email keyboard

  @smoke @happy-path @mvp-scope
  Scenario: Completing basic information takes the caretaker to Photo & identity check
    When I enter "Anita Deshmukh" in "Full name (as on Aadhaar)"
    And I select the sex "Female"
    And I enter "32" in "Age"
    And I enter "anita.d@example.com" in "Email"
    And I enter "9123456789" in "Emergency contact"
    And I enter "B-4, Shanti Nagar, Hadapsar, Pune 411028" in "Residential address"
    And I enter "Home nurse" in "Occupation"
    And I select the marital status "Married"
    And I tap "Save and continue"
    Then my basic information should be saved
    And I should see the "Photo & identity check" screen
    And I should not see the "Aadhaar & PAN" screen

  @happy-path @mvp-scope
  Scenario: Basic information step is marked done on the checklist
    Given I have completed and saved basic information with valid data
    When I return to the "KYC checklist" screen
    Then the "Basic information" step should be marked "Done"
    And the "Photo & video KYC" step should be marked "Current"

  @happy-path
  Scenario: Optional fields can be left empty
    When I fill in all required fields with valid data
    And I leave "Occupation" empty
    And I do not select a marital status
    And I tap "Save and continue"
    Then my basic information should be saved without occupation and marital status
    And I should see the "Photo & identity check" screen

  @happy-path
  Scenario: Save and finish later keeps partial progress
    When I enter "Anita Deshmukh" in "Full name (as on Aadhaar)"
    And I select the sex "Female"
    And I tap "Save and finish later"
    Then the entered values should be saved as a draft
    And I should see the "KYC checklist" screen
    And the "Basic information" step should still be marked "Current"

  @happy-path
  Scenario: Resuming a draft restores entered values
    Given I saved a basic information draft with name "Anita Deshmukh" and sex "Female"
    When I open the "Basic information" step from the checklist
    Then "Full name (as on Aadhaar)" should contain "Anita Deshmukh"
    And the sex "Female" should be selected

  @ui-state
  Scenario: Save and continue is disabled until all required fields are valid
    Then the "Save and continue" button should be disabled
    When I fill in all required fields with valid data except "Residential address"
    Then the "Save and continue" button should be disabled
    And I should see a caption under the button explaining "1 required field left"
    When I enter "Hadapsar, Pune 411028" in "Residential address"
    Then the "Save and continue" button should be enabled

  @ui-state
  Scenario: Save and finish later is always available
    Then the "Save and finish later" button should be enabled

  @negative @validation
  Scenario Outline: Missing required fields show inline errors
    Given I have filled the basic information form with valid data
    When I clear the "<field>" input
    And I move focus out of the "<field>" input
    Then I should see the inline error "<error>" under "<field>"
    And the "Save and continue" button should be disabled

    Examples:
      | field                      | error                              |
      | Full name (as on Aadhaar)  | Enter your full name as on Aadhaar |
      | Age                        | Enter your age                     |
      | Email                      | Enter your email address           |
      | Emergency contact          | Enter an emergency contact number  |
      | Residential address        | Enter your residential address     |

  @negative @validation
  Scenario: Sex must be selected
    Given I have filled all required text fields with valid data
    And no sex option is selected
    Then the "Save and continue" button should be disabled

  @negative @validation
  Scenario Outline: Caretaker must be at least 18
    When I enter "<age>" in "Age"
    And I move focus out of the "Age" input
    Then I should see the inline error "<error>" under "Age"
    And the "Save and continue" button should be disabled

    Examples:
      | age | error                                 |
      | 0   | You must be at least 18 to sign up    |
      | 16  | You must be at least 18 to sign up    |
      | 17  | You must be at least 18 to sign up    |
      | 71  | Enter an age between 18 and 70        |

  @validation
  Scenario Outline: Boundary ages are accepted
    When I enter "<age>" in "Age"
    And I move focus out of the "Age" input
    Then no inline error should be shown under "Age"

    Examples:
      | age |
      | 18  |
      | 19  |
      | 70  |

  @negative @validation
  Scenario Outline: Invalid email formats are rejected
    When I enter "<email>" in "Email"
    And I move focus out of the "Email" input
    Then I should see the inline error "Enter a valid email address" under "Email"

    Examples:
      | email                 |
      | anita                 |
      | anita@                |
      | anita@example         |
      | @example.com          |
      | anita@@example.com    |
      | anita example@mail.com|

  @validation
  Scenario Outline: Valid email formats are accepted
    When I enter "<email>" in "Email"
    And I move focus out of the "Email" input
    Then no inline error should be shown under "Email"

    Examples:
      | email                     |
      | anita.d@example.com       |
      | anita+care@example.co.in  |
      | ANITA_D@Example.org       |

  @negative @validation
  Scenario Outline: Invalid emergency contact numbers are rejected
    When I enter "<number>" in "Emergency contact"
    And I move focus out of the "Emergency contact" input
    Then I should see the inline error "<error>" under "Emergency contact"

    Examples:
      | number     | error                                             |
      | 12345      | Enter a valid 10-digit mobile number              |
      | 0123456789 | Enter a valid 10-digit mobile number              |
      | 5123456789 | Enter a valid 10-digit mobile number              |
      | 9988776655 | Emergency contact must be different from your number |

  @negative @validation
  Scenario Outline: Invalid full name values are rejected
    When I enter "<name>" in "Full name (as on Aadhaar)"
    And I move focus out of the "Full name (as on Aadhaar)" input
    Then I should see the inline error "<error>" under "Full name (as on Aadhaar)"

    Examples:
      | name        | error                                |
      | A           | Name must have at least 2 characters |
      | Anita123    | Name can only contain letters        |
      | Anita#D     | Name can only contain letters        |

  @validation
  Scenario: Helper text reminds the caretaker to match Aadhaar
    When I focus the "Full name (as on Aadhaar)" input
    Then I should see the helper text "Enter your name exactly as it appears on your Aadhaar"

  @ui-state
  Scenario: Marital status is single-select
    When I select the marital status "Single"
    And I select the marital status "Married"
    Then only "Married" should be selected as marital status

  @negative
  Scenario: Email already used by another caretaker
    Given the email "taken@example.com" is already registered to another caretaker
    And I have filled the basic information form with valid data
    When I enter "taken@example.com" in "Email"
    And I tap "Save and continue"
    Then I should see the inline error "This email is already in use" under "Email"
    And I should remain on the "Basic information" screen

  @negative
  Scenario: Save fails because of a network error
    Given I have filled the basic information form with valid data
    And the device has no internet connection
    When I tap "Save and continue"
    Then I should see the error "No internet connection. Check your connection and try again."
    And all entered values should be kept
    And I should remain on the "Basic information" screen

  @ui-state
  Scenario: Save and continue shows a loading state and prevents double submission
    Given I have filled the basic information form with valid data
    When I tap "Save and continue" twice quickly
    Then the "Save and continue" button should show a loading indicator
    And exactly one save request should be sent

  @navigation
  Scenario: Back with unsaved changes asks before discarding
    Given I have entered "Anita Deshmukh" in "Full name (as on Aadhaar)"
    And I have not saved
    When I press the back button
    Then I should see a dialog "Leave without saving?"
    And the dialog should offer "Save and finish later" and "Discard"
    When I choose "Discard"
    Then I should see the "KYC checklist" screen
    And no draft should be saved

  @navigation
  Scenario: Back with unsaved changes - saving from the dialog
    Given I have entered "Anita Deshmukh" in "Full name (as on Aadhaar)"
    When I press the back button
    And I choose "Save and finish later" in the dialog
    Then the entered values should be saved as a draft
    And I should see the "KYC checklist" screen

  @navigation
  Scenario: Back with no changes returns to the checklist without a dialog
    When I press the back button
    Then I should see the "KYC checklist" screen
    And no dialog should be shown
