/// Holds transient navigation state for the active exam-taking session.
/// Timer and persistence lifecycles remain owned by their existing controllers.
class ExamTakingSessionController {
  int currentQuestionNumber = 1;
  bool showQuestionNavigator = false;

  void selectQuestion(int number, {required int questionCount}) {
    if (questionCount < 1) {
      currentQuestionNumber = 1;
      return;
    }
    currentQuestionNumber = number.clamp(1, questionCount).toInt();
  }

  void nextQuestion({required int questionCount}) {
    if (currentQuestionNumber < questionCount) {
      currentQuestionNumber++;
    }
  }

  void previousQuestion({required int questionCount}) {
    if (currentQuestionNumber > 1) {
      currentQuestionNumber--;
    }
    if (questionCount < 1) currentQuestionNumber = 1;
  }

  void toggleQuestionNavigator() {
    showQuestionNavigator = !showQuestionNavigator;
  }
}
