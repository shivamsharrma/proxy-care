@onboarding @shared @screen-01
Feature: Welcome and role selection (Screen 01)
  As a first-time visitor to Proxy Care
  I want to understand the service and choose whether I am a family User or a Caretaker
  So that I am taken into the right onboarding journey

  # Source: proxy-care-api-context.md §4 "01 Welcome / choose role"
  # Role USER -> 02 Mobile number -> 03 Verify OTP -> 04 User profile
  # Role CARETAKER -> 02 Mobile number -> 03 Verify OTP -> C1 KYC checklist

  Background:
    Given the app is freshly installed
    And no user session exists on the device
    When I launch the app

  @smoke @happy-path
  Scenario: Welcome screen shows value propositions, language toggle and role choices
    Then I should see the "Welcome" screen
    And I should see the Proxy Care value propositions
    And I should see the language toggle with options "English" and "हिन्दी"
    And "English" should be selected in the language toggle by default
    And I should see the role option "I'm booking for my family"
    And I should see the role option "I'm a caretaker"
    And I should see links to "Terms" and "Privacy"

  @smoke @happy-path
  Scenario Outline: Choosing a role takes the visitor to the shared mobile number screen
    When I choose the role "<role>"
    Then I should see the "Mobile number" screen
    And the onboarding role should be stored as "<role_enum>"

    Examples:
      | role                       | role_enum |
      | I'm booking for my family  | USER      |
      | I'm a caretaker            | CARETAKER |

  @happy-path @i18n
  Scenario: Switching the language to Hindi updates the whole Welcome screen
    When I select "हिन्दी" in the language toggle
    Then all Welcome screen text should be displayed in Hindi
    And "हिन्दी" should be shown as selected in the language toggle

  @i18n
  Scenario: Selected language persists across the onboarding flow
    Given I have selected "हिन्दी" in the language toggle
    When I choose the role "I'm booking for my family"
    Then the "Mobile number" screen should be displayed in Hindi

  @i18n
  Scenario: Selected language persists after the app is restarted
    Given I have selected "हिन्दी" in the language toggle
    When I close and relaunch the app
    Then the "Welcome" screen should be displayed in Hindi

  @i18n
  Scenario: Switching back to English
    Given I have selected "हिन्दी" in the language toggle
    When I select "English" in the language toggle
    Then all Welcome screen text should be displayed in English

  @navigation
  Scenario Outline: Opening legal documents and returning to Welcome
    When I tap the "<link>" link
    Then the "<document>" document should open
    When I go back
    Then I should see the "Welcome" screen
    And no role should be selected

    Examples:
      | link    | document         |
      | Terms   | Terms of Service |
      | Privacy | Privacy Policy   |

  @navigation
  Scenario: Android back on Welcome exits the app instead of navigating elsewhere
    When I press the device back button
    Then the app should close
    And no onboarding data should be saved

  @ui-state @accessibility
  Scenario: Role options are announced correctly by a screen reader
    Given the screen reader is turned on
    When I move focus to each role option
    Then each role option should be announced as a button with its full label

  @ui-state @accessibility
  Scenario: Welcome screen does not clip text at the largest font size
    Given the device font size is set to the largest setting
    Then all Welcome screen text should be fully visible without truncation
    And both role options should remain tappable
