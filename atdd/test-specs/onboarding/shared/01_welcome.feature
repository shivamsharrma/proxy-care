@onboarding @shared @screen-01
Feature: Welcome (Screen 01)
  As a first-time visitor to the User app or the Caretaker app
  I want to understand the service and start signing up
  So that I am taken into that app's onboarding journey

  # Source: proxy-care-api-context.md §4 "01 Welcome"
  # DECISION: there are two apps, the User app and the Caretaker app. The app decides the
  #           role, so Welcome has no role picker.
  # User app      -> 02 Mobile number -> 03 Verify OTP -> 04 User profile
  # Caretaker app -> 02 Mobile number -> 03 Verify OTP -> C1 KYC checklist
  # ASSUMPTION: the "Get started" label is placeholder copy.

  # The Background and every scenario apply to both the User app and the Caretaker app.
  Background:
    Given the app is freshly installed
    And no user session exists on the device
    When I launch the app

  @smoke @happy-path
  Scenario: Welcome screen shows value propositions, language toggle and Get started
    Then I should see the "Welcome" screen
    And I should see the Proxy Care value propositions for this app
    And I should see the language toggle with options "English" and "हिन्दी"
    And "English" should be selected in the language toggle by default
    And I should see the "Get started" button
    And I should see links to "Terms" and "Privacy"
    And I should not see any role choice

  @smoke @happy-path
  Scenario Outline: Get started takes the visitor to the shared mobile number screen as the app's role
    When I tap "Get started" in the <app>
    Then I should see the "Mobile number" screen
    And the sign-up should be for the role "<role_enum>"

    Examples:
      | app           | role_enum |
      | User app      | USER      |
      | Caretaker app | CARETAKER |

  @happy-path @i18n
  Scenario: Switching the language to Hindi updates the whole Welcome screen
    When I select "हिन्दी" in the language toggle
    Then all Welcome screen text should be displayed in Hindi
    And "हिन्दी" should be shown as selected in the language toggle

  @i18n
  Scenario: Selected language persists across the onboarding flow
    Given I have selected "हिन्दी" in the language toggle
    When I tap "Get started"
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
  Scenario: Get started is announced correctly by a screen reader
    Given the screen reader is turned on
    When I move focus to "Get started"
    Then it should be announced as a button with its full label

  @ui-state @accessibility
  Scenario: Welcome screen does not clip text at the largest font size
    Given the device font size is set to the largest setting
    Then all Welcome screen text should be fully visible without truncation
    And "Get started" should remain tappable
