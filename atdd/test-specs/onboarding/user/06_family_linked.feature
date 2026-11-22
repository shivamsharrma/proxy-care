@onboarding @user-app @screen-06
Feature: Family linked (Screen 06)
  As a family User who has added family members
  I want to see everyone I have linked and add or edit them
  So that I can start booking a caretaker

  # Source: proxy-care-api-context.md §4 "06 Family linked"
  # Displays: list of patients (initials, name, relation, age, sex, mobility badge);
  #           "you only pay when asked" note.
  # Actions: edit patient; add another; Book a caretaker -> B1.

  Background:
    Given I am a verified User with a saved profile
    And I have linked the family member "Suresh Sharma", "Father", age 68, "Male", mobility "WHEELCHAIR"
    And I am on the "Family linked" screen

  @smoke @happy-path
  Scenario: Linked family member is listed with all details
    Then I should see a patient card for "Suresh Sharma"
    And the card should show the initials "SS"
    And the card should show the relation "Father"
    And the card should show "68" and "Male"
    And the card should show the mobility badge "Wheelchair"
    And I should see the note that I only pay when asked

  @happy-path
  Scenario Outline: Mobility badge text matches the category
    Given I have linked a family member with mobility "<enum>"
    Then that family member's card should show the mobility badge "<badge>"

    Examples:
      | enum       | badge        |
      | AMBULATORY | Walks on own |
      | WHEELCHAIR | Wheelchair   |
      | BEDRIDDEN  | Bedridden    |

  @happy-path
  Scenario: Adding another family member
    When I tap "Add another"
    Then I should see an empty "Add family member" screen
    When I add the family member "Lata Sharma", "Mother", age 65, "Female", mobility "Walks on own"
    Then I should see the "Family linked" screen
    And I should see 2 patient cards in the order they were added

  @happy-path
  Scenario: Editing a linked family member
    When I tap edit on the patient card for "Suresh Sharma"
    Then I should see the "Add family member" screen pre-filled with "Suresh Sharma"'s details
    When I select the mobility option "Bedridden"
    And I tap "Save family member"
    Then I should see the "Family linked" screen
    And the card for "Suresh Sharma" should show the mobility badge "Bedridden"
    And no new patient should be created

  @navigation
  Scenario: Discarding an edit leaves the patient unchanged
    When I tap edit on the patient card for "Suresh Sharma"
    And I change the "Age" to "70"
    And I press the back button
    Then I should see the "Family linked" screen
    And the card for "Suresh Sharma" should still show "68"

  @smoke @happy-path
  Scenario: Finishing onboarding and going to Home
    When I tap "Book a caretaker"
    Then I should see the "Home (B1)" screen
    And "Suresh Sharma" should appear in the Home patient list
    And my onboarding should be marked complete

  @navigation
  Scenario: Back from Home does not return to onboarding
    Given I have tapped "Book a caretaker" and I am on the "Home (B1)" screen
    When I press the back button
    Then I should not see the "Family linked" screen
    And I should not see any onboarding screen

  @navigation
  Scenario: Relaunching after onboarding opens Home directly
    Given I have tapped "Book a caretaker"
    When I close and relaunch the app
    Then I should see the "Home (B1)" screen

  @negative
  Scenario: Family list fails to load
    Given the family list request fails
    When the "Family linked" screen loads
    Then I should see the error "Couldn't load your family. Try again."
    And I should see a "Retry" button
    When the request succeeds and I tap "Retry"
    Then I should see the patient card for "Suresh Sharma"

  @ui-state
  Scenario: Loading skeleton while the family list loads
    Given the family list request is slow
    When the "Family linked" screen loads
    Then I should see skeleton placeholders for the patient cards
    And the "Book a caretaker" button should be disabled until the list has loaded

  @edge-case
  Scenario: Long patient names are shown without breaking the layout
    Given I have linked a family member with the name "Venkata Subramaniam Ramachandran Iyer"
    Then that patient card should show the name without overlapping other card elements
