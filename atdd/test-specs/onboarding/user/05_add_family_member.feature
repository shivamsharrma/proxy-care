@onboarding @user-app @screen-05
Feature: Add family member - Stage B (Screen 05)
  As a family User
  I want to add the family member who needs a caretaker
  So that I can book visits for them

  # Source: proxy-care-api-context.md §4 "05 Add family member (Stage B)"
  # Inputs: relation* (Father, Mother, Spouse, Grandparent, Sibling, Other), full name*, age*,
  #         sex*, mobile (optional; receives pickup OTP), "lives at my address" toggle (else address*),
  #         mobility category* (AMBULATORY / WHEELCHAIR / BEDRIDDEN), health notes (optional).
  # Action: Save family member -> 06.
  # ASSUMPTION: patient age whole number 0-120; health notes max 500 chars; copy is placeholder.

  Background:
    Given I am a verified User with a saved profile
    And my profile address is "Flat 12, Sunrise Apartments, Kothrud, Pune 411038"
    And I am on the "Add family member" screen

  @ui-state
  Scenario: Add family member form shows all fields
    Then I should see the relation options "Father", "Mother", "Spouse", "Grandparent", "Sibling" and "Other"
    And I should see the required fields "Full name", "Age" and "Sex"
    And I should see the optional field "Mobile"
    And I should see the toggle "Lives at my address"
    And I should see the mobility options "Walks on own", "Wheelchair" and "Bedridden"
    And I should see the optional field "Health notes"

  @ui-state
  Scenario: "Lives at my address" is on by default and hides the address field
    Then the "Lives at my address" toggle should be on
    And the "Address" field should not be shown

  @ui-state
  Scenario: Turning off "Lives at my address" shows a required address field
    When I turn off the "Lives at my address" toggle
    Then the "Address" field should be shown and marked as required

  @smoke @happy-path
  Scenario: Adding a parent who lives with the user
    When I select the relation "Father"
    And I enter "Suresh Sharma" in "Full name"
    And I enter "68" in "Age"
    And I select the sex "Male"
    And I select the mobility option "Wheelchair"
    And I enter "Diabetic, needs help on stairs" in "Health notes"
    And I tap "Save family member"
    Then a patient "Suresh Sharma" should be linked to my account with relation "FATHER"
    And the patient address should be "Flat 12, Sunrise Apartments, Kothrud, Pune 411038"
    And the patient mobility category should be "WHEELCHAIR"
    And I should see the "Family linked" screen

  @happy-path
  Scenario: Adding a family member who lives at a different address with own mobile
    When I select the relation "Mother"
    And I enter "Lata Iyer" in "Full name"
    And I enter "72" in "Age"
    And I select the sex "Female"
    And I enter "9123456780" in "Mobile"
    And I turn off the "Lives at my address" toggle
    And I enter "5 Lake View Road, Chennai 600028" in "Address"
    And I select the mobility option "Walks on own"
    And I tap "Save family member"
    Then a patient "Lata Iyer" should be linked with the address "5 Lake View Road, Chennai 600028"
    And the patient mobile should be "+91 9123456780"
    And I should see the "Family linked" screen

  @happy-path
  Scenario Outline: Each mobility category is saved with the right enum
    Given I have filled the family member form with valid data except mobility
    When I select the mobility option "<option>"
    And I tap "Save family member"
    Then the patient mobility category should be "<enum>"

    Examples:
      | option       | enum       |
      | Walks on own | AMBULATORY |
      | Wheelchair   | WHEELCHAIR |
      | Bedridden    | BEDRIDDEN  |

  @happy-path
  Scenario Outline: Each relation is saved with the right enum
    Given I have filled the family member form with valid data except relation
    When I select the relation "<relation>"
    And I tap "Save family member"
    Then the patient relation should be "<enum>"

    Examples:
      | relation    | enum        |
      | Father      | FATHER      |
      | Mother      | MOTHER      |
      | Spouse      | SPOUSE      |
      | Grandparent | GRANDPARENT |
      | Sibling     | SIBLING     |
      | Other       | OTHER       |

  @ui-state
  Scenario: Only one relation and one mobility option can be selected
    When I select the relation "Father"
    And I select the relation "Mother"
    Then only "Mother" should be selected as relation
    When I select the mobility option "Wheelchair"
    And I select the mobility option "Bedridden"
    Then only "Bedridden" should be selected as mobility

  @ui-state
  Scenario: Save is disabled until every required field is filled
    Then the "Save family member" button should be disabled
    When I fill in all required fields except "Mobility"
    Then the "Save family member" button should be disabled
    When I select the mobility option "Walks on own"
    Then the "Save family member" button should be enabled

  @negative @validation
  Scenario Outline: Missing required fields block saving
    Given I have filled the family member form with valid data
    When I clear the required field "<field>"
    Then I should see the inline error "<error>" under "<field>"
    And the "Save family member" button should be disabled

    Examples:
      | field     | error                              |
      | Relation  | Choose how this person is related   |
      | Full name | Enter their full name               |
      | Age       | Enter their age                     |
      | Sex       | Choose their sex                    |
      | Mobility  | Choose how they move around         |

  @negative @validation
  Scenario: Address is required when "Lives at my address" is off
    Given I have filled the family member form with valid data
    When I turn off the "Lives at my address" toggle
    And I leave the "Address" field empty
    Then the "Save family member" button should be disabled
    And I should see the inline error "Enter their address" after the field loses focus

  @negative @validation
  Scenario Outline: Invalid age for the family member
    When I enter "<age>" in "Age"
    And I move focus out of the "Age" input
    Then I should see the inline error "Enter an age between 0 and 120" under "Age"

    Examples:
      | age |
      | 121 |
      | 999 |

  @negative @validation
  Scenario Outline: Optional mobile must be valid when entered
    When I enter "<mobile>" in "Mobile"
    And I move focus out of the "Mobile" input
    Then I should see the inline error "Enter a valid 10-digit mobile number" under "Mobile"

    Examples:
      | mobile     |
      | 12345      |
      | 0123456789 |
      | 5123456789 |

  @validation
  Scenario: Leaving the optional mobile empty is allowed
    Given I have filled the family member form with valid data
    And the "Mobile" field is empty
    When I tap "Save family member"
    Then the patient should be saved without a mobile number
    And I should see the "Family linked" screen

  @validation
  Scenario: Helper text explains why the family member's mobile is useful
    When I focus the "Mobile" input
    Then I should see the helper text that this number receives the pickup code

  @validation
  Scenario: Health notes character limit
    When I type 501 characters into "Health notes"
    Then the "Health notes" field should contain 500 characters
    And I should see the counter "500/500"

  @edge-case
  Scenario: Turning the address toggle back on discards the separate address
    Given I have turned off the "Lives at my address" toggle
    And I have entered "5 Lake View Road, Chennai 600028" in "Address"
    When I turn on the "Lives at my address" toggle
    And I complete the form and tap "Save family member"
    Then the patient address should be "Flat 12, Sunrise Apartments, Kothrud, Pune 411038"

  @negative
  Scenario: Save fails because of a network error
    Given I have filled the family member form with valid data
    And the device has no internet connection
    When I tap "Save family member"
    Then I should see the error "No internet connection. Check your connection and try again."
    And all entered values should be kept

  @ui-state
  Scenario: Save shows a loading state and avoids duplicate patients
    Given I have filled the family member form with valid data
    When I tap "Save family member" twice quickly
    Then the "Save family member" button should show a loading indicator
    And exactly one patient should be created

  @navigation
  Scenario: Back from Add family member returns to User profile with saved data
    When I press the back button
    Then I should see the "User profile" screen
    And my saved profile values should be shown
