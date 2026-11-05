/// Coordinates exam-taking lifecycle guards independently from widget state.
/// Timer ownership and result persistence remain in their existing controllers.
class ExamTakingLifecycleController {
  bool isTaking = false;
  bool isFinishing = false;
  bool isSavingResult = false;

  void begin() { isTaking = true; isFinishing = false; }
  void leave() { isTaking = false; isFinishing = false; }
  bool beginFinish({bool automatic = false}) {
    if (!isTaking || (isFinishing && !automatic)) return false;
    isFinishing = true;
    return true;
  }
  void cancelFinish() { isFinishing = false; }
  void complete() { isTaking = false; isFinishing = false; }
  bool beginSaveResult() {
    if (isSavingResult) return false;
    isSavingResult = true;
    return true;
  }
  void endSaveResult() { isSavingResult = false; }
}
