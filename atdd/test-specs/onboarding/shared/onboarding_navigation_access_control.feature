@onboarding @navigation @access-control
Feature: Onboarding navigation, routing and access control
  As the Proxy Care app
  I want to send each person to the right screen for their role and progress
  So that nobody skips required steps or lands in the wrong app

  # Covers cross-screen rules for 01-06 (User) and C1, C2, C4, C5, C6 (Caretaker).
  # MVP RULE: C3 Aadhaar & PAN is not integrated. C2 -> C4 directly. No route, deep link or
  #           checklist entry may open C3.
  # DECISION: two apps, the User app and the Caretaker app; the app decides the role.
  # DECISION: one mobile number can hold both roles (USER and CARETAKER) on one account.
  # ASSUMPTION: copy is placeholder.

  @smoke
  Scenario Outline: Cold start routes the person by session and onboarding progress
    Given the device has "<session>" in the <app>
    When I launch the <app>
    Then I should see the "<screen>" screen

    Examples: User app
      | app           | session                                                      | screen            |
      | User app      | no session                                                   | Welcome           |
      | User app      | a session with no profile                                    | User profile      |
      | User app      | a session with a profile and no family members               | Add family member |
      | User app      | a session with a profile and at least one family member      | Home (B1)         |

    Examples: Caretaker app
      | app           | session                                                      | screen            |
      | Caretaker app | no session                                                   | Welcome           |
      | Caretaker app | a session with KYC IN_PROGRESS                               | KYC checklist     |
      | Caretaker app | a session with KYC SUBMITTED                                 | Under review      |
      | Caretaker app | a session with KYC APPROVED                                  | Home (P1)         |
      | Caretaker app | a session with KYC REJECTED                                  | Under review      |

  @mvp-scope
  Scenario: The full MVP caretaker onboarding path
    Given I am signing up in the Caretaker app
    When I verify my mobile number with the correct OTP
    Then I should see the "KYC checklist" screen
    When I complete "Basic information" and tap "Save and continue"
    Then I should see the "Photo & identity check" screen
    When I take a photo, pick a slot and tap "Book call"
    Then I should see the "Payout account" screen
    When I enter valid bank details and tap "Submit for review"
    Then I should see the "Under review" screen

  @mvp-scope @IgnoreForMVP
  Scenario: A deep link to Aadhaar & PAN is not available in the MVP
    Given I am a caretaker with KYC "IN_PROGRESS"
    When I open a deep link to the Aadhaar & PAN step
    Then I should see the "KYC checklist" screen
    And I should not see the "Aadhaar & PAN" screen

  @smoke
  Scenario: The full User onboarding path
    Given I am signing up in the User app
    When I verify my mobile number with the correct OTP
    Then I should see the "User profile" screen
    When I complete my profile and tap "Continue"
    Then I should see the "Add family member" screen
    When I add a family member and tap "Save family member"
    Then I should see the "Family linked" screen
    When I tap "Book a caretaker"
    Then I should see the "Home (B1)" screen

  @access-control
  Scenario: A User cannot skip Add family member by deep linking to Home
    Given I am a User with a profile and no family members
    When I open a deep link to the Home screen
    Then I should see the "Add family member" screen

  @access-control
  Scenario Outline: A caretaker cannot open later KYC steps before earlier ones are done
    Given I am a caretaker who has completed "<done>"
    When I try to open the "<target>" step
    Then I should see the "KYC checklist" screen
    And the "<current>" step should be marked "Current"

    Examples:
      | done              | target            | current           |
      | Mobile number     | Photo & video KYC | Basic information |
      | Mobile number     | Payout account    | Basic information |
      | Basic information | Payout account    | Photo & video KYC |

  @access-control
  Scenario: A caretaker under review cannot go online
    Given I am a caretaker with KYC "SUBMITTED"
    When I open "Home (P1)"
    Then the online/offline toggle should be disabled
    And I should see a note that I can go online after approval

  @access-control @multi-role
  Scenario: A caretaker's mobile number can also sign up in the User app
    Given the number "9988776655" belongs to a caretaker account with KYC "APPROVED"
    And I am signing up in the User app
    When I enter the mobile number "9988776655" and verify the correct OTP
    Then I should see the "User profile" screen
    And the caretaker's KYC status should still be "APPROVED"

  @access-control @multi-role
  Scenario: A user's mobile number can also sign up in the Caretaker app
    Given the number "9876543210" belongs to a user account with at least one family member
    And I am signing up in the Caretaker app
    When I enter the mobile number "9876543210" and verify the correct OTP
    Then I should see the "KYC checklist" screen
    And the user's family members should be unchanged

  @access-control
  Scenario: Caretaker screens are not reachable from the User app
    Given I am a fully onboarded User
    When I open a deep link to the caretaker "KYC checklist"
    Then I should see the "Home (B1)" screen

  @access-control
  Scenario: User onboarding screens are not reachable from the Caretaker app
    Given I am a caretaker with KYC "IN_PROGRESS"
    When I open a deep link to the "Add family member" screen
    Then I should see the "KYC checklist" screen

  @access-control
  Scenario: An expired session sends the person back to sign in
    Given I am a User with a profile and my session has expired
    When I launch the app
    Then I should see the "Mobile number" screen
    And after verifying the OTP I should return to where I left off

  @navigation
  Scenario Outline: Device back button behaviour across onboarding
    Given I am on the "<screen>" screen
    When I press the device back button
    Then I should see "<result>"

    Examples:
      | screen                 | result                                   |
      | Welcome                | the app closes                           |
      | Mobile number          | the Welcome screen                       |
      | Verify OTP             | the Mobile number screen                 |
      | User profile           | the app closes                           |
      | Add family member      | the User profile screen                  |
      | Family linked          | the app closes                           |
      | KYC checklist          | the app closes                           |
      | Basic information      | the KYC checklist screen                 |
      | Photo & identity check | the KYC checklist screen                 |
      | Payout account         | the KYC checklist screen                 |
      | Under review           | the app closes                           |

  @ui-state
  Scenario: Offline banner during onboarding
    Given I am on any onboarding screen
    When the device loses internet connection
    Then I should see an offline banner
    And primary actions that need the network should show an error when tapped
    When the connection returns
    Then the offline banner should disappear
