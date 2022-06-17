/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller.
*/

import UIKit
import Vision
import GameKit

var finishedExercise = false
var exerciseCount = 0

@available(iOS 14.0, *)
class MainViewController: UIViewController, GKLocalPlayerListener, GKGameCenterControllerDelegate {
    /// The full-screen view that presents the pose on top of the video frames.
    @IBOutlet var imageView: UIImageView!

    /// The stack that contains the labels at the middle of the leading edge.
    @IBOutlet weak var labelStack: UIStackView!

    @IBOutlet var countStack: UIStackView!
    
    /// The label that displays the model's exercise action prediction.
    @IBOutlet weak var actionLabel: UILabel!

    /// The label that displays the model's confidence in its prediction.
    @IBOutlet weak var confidenceLabel: UILabel!

    @IBOutlet weak var countLabel: UILabel!
    
    /// The stack that contains the buttons at the bottom of the leading edge.
    @IBOutlet weak var buttonStack: UIStackView!

    @IBOutlet weak var learnStack: UIStackView!
    
    /// The button users tap to show a summary view.
    @IBOutlet weak var summaryButton: UIButton!

    /// The button users tap to toggle between the front- and back-facing
    /// cameras.
    @IBOutlet weak var cameraButton: UIButton!

    @IBOutlet weak var learnButton: UIButton!
    /// Captures the frames from the camera and creates a frame publisher.
    var videoCapture: VideoCapture!

    /// Builds a chain of Combine publishers from a frame publisher.
    ///
    /// The video-processing chain provides the view controller with:
    /// - Each video camera frame as a `CGImage`.
    /// - A `Pose` array of any people `Vision` observed in that frame.
    /// - Action predictions from the prominent person's poses over time.
    var videoProcessingChain: VideoProcessingChain!

    /// Maintains the aggregate time for each action the model predicts.
    /// - Tag: actionFrameCounts
    var actionFrameCounts = [String: Int]()
    
    var gcEnabled = Bool() // Check if the user has Game Center enabled
    var gcDefaultLeaderBoard = String() // Check the default leaderboardID
    
    func authenticateLocalPlayer() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                self.view?.window?.rootViewController?.present(viewController, animated: true)
            } else if localPlayer.isAuthenticated {
                NSLog("local player is authenticated")
                localPlayer.register(self)
            } else {
                NSLog("player is not authenticated!!!")
            }
        }
    }
    
}

// MARK: - View Controller Events
extension MainViewController {
    /// Configures the main view after it loads.
    override func viewDidLoad() {
        super.viewDidLoad()

        // Disable the idle timer to prevent the screen from locking.
        UIApplication.shared.isIdleTimerDisabled = true

        // Round the corners of the stack and button views.
        let views = [labelStack, countStack, buttonStack, cameraButton, summaryButton, learnButton]
        views.forEach { view in
            view?.layer.cornerRadius = 10
            view?.overrideUserInterfaceStyle = .dark
        }

        // Set the view controller as the video-processing chain's delegate.
        videoProcessingChain = VideoProcessingChain()
        videoProcessingChain.delegate = self

        // Begin receiving frames from the video capture.
        videoCapture = VideoCapture()
        videoCapture.delegate = self

        updateUILabelsWithPrediction(.startingPrediction)
        
        if Date().date != UserDefaults.standard.string(forKey: "Daily-Date") || UserDefaults.standard.string(forKey: "Daily-Date") == nil {
            UserDefaults.standard.set(String(Date().date), forKey: "Daily-Date")
            UserDefaults.standard.set(0, forKey: "Daily-Count")
        }
        
        let formatter = DateFormatter(); formatter.dateFormat = "dd"
        let week = formatter.string(from: Date.today().previous(.monday))
        if week != UserDefaults.standard.string(forKey: "Weekly-Date") || UserDefaults.standard.string(forKey: "Weekly-Date") == nil {
            UserDefaults.standard.set(String(week), forKey: "Weekly-Date")
            UserDefaults.standard.set(0, forKey: "Weekly-Count")
        }
        
//        print(UserDefaults.standard.integer(forKey: "All-Time-Count"), UserDefaults.standard.integer(forKey: "Weekly-Count"), UserDefaults.standard.integer(forKey: "Daily-Count"))
        
        GKAccessPoint.shared.isActive = true
        GKAccessPoint.shared.location = .topLeading
        authenticateLocalPlayer()
        
    }

    /// Configures the video captures session with the device's orientation.
    ///
    /// This is the app's first opportunity to retrieve the device's
    /// physical orientation with its hardware sensors.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Update the device's orientation.
//        videoCapture.updateDeviceOrientation()
    }

    /// Notifies the video capture when the device rotates to a new orientation.
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        // Update the the camera's orientation to match the device's.
//        videoCapture.updateDeviceOrientation()
    }
    
    func authenticatePlayer() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = {
            (view, error) in
            if view != nil {
                self.present(view!, animated: true, completion: nil)
            } else {
                print(GKLocalPlayer.local.isAuthenticated)
            }
        }
    }
    
}

extension Date {
    static func today() -> Date {
        return Date().localDate()
      }
    func localDate() -> Date {
            let nowUTC = Date()
            let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: nowUTC))
            guard let localDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset), to: nowUTC) else {return Date()}
            return localDate
        }
    func next(_ weekday: Weekday, considerToday: Bool = false) -> Date {
        return get(.next,
                   weekday,
                   considerToday: considerToday)
      }

      func previous(_ weekday: Weekday, considerToday: Bool = false) -> Date {
        return get(.previous,
                   weekday,
                   considerToday: considerToday)
      }

      func get(_ direction: SearchDirection,
               _ weekDay: Weekday,
               considerToday consider: Bool = false) -> Date {

        let dayName = weekDay.rawValue

        let weekdaysName = getWeekDaysInEnglish().map { $0.lowercased() }

        assert(weekdaysName.contains(dayName), "weekday symbol should be in form \(weekdaysName)")

        let searchWeekdayIndex = weekdaysName.firstIndex(of: dayName)! + 1

        let calendar = Calendar(identifier: .gregorian)

        if consider && calendar.component(.weekday, from: self) == searchWeekdayIndex {
          return self
        }

        var nextDateComponent = calendar.dateComponents([.hour, .minute, .second], from: self)
        nextDateComponent.weekday = searchWeekdayIndex

        let date = calendar.nextDate(after: self,
                                     matching: nextDateComponent,
                                     matchingPolicy: .nextTime,
                                     direction: direction.calendarSearchDirection)
        return date!
      }
    
    var weekday: String {
        let formatter = DateFormatter(); formatter.dateFormat = "E"
        return formatter.string(from: self as Date)
    }
    var date: String {
        let formatter = DateFormatter(); formatter.dateFormat = "d"
        return formatter.string(from: self as Date)
    }
}

extension Date {
  func getWeekDaysInEnglish() -> [String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    return calendar.weekdaySymbols
  }

  enum Weekday: String {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
  }

  enum SearchDirection {
    case next
    case previous

    var calendarSearchDirection: Calendar.SearchDirection {
      switch self {
      case .next:
        return .forward
      case .previous:
        return .backward
      }
    }
  }
}

// MARK: - Button Events
extension MainViewController {
    /// Toggles the video capture between the front- and back-facing cameras.
    @IBAction func onCameraButtonTapped(_: Any) {
        videoCapture.toggleCameraSelection()
    }

    /// Presents a summary view of the user's actions and their total times.
    @IBAction func onSummaryButtonTapped() {
//        let main = UIStoryboard(name: "Main", bundle: nil)
//
//        // Get the view controller based on its name.
//        let vcName = "SummaryViewController"
//        let viewController = main.instantiateViewController(identifier: vcName)
//
//        // Cast it as a `SummaryViewController`.
//        guard let summaryVC = viewController as? SummaryViewController else {
//            fatalError("Couldn't cast the Summary View Controller.")
//        }
//
//        // Copy the current actions times to the summary view.
//        summaryVC.actionFrameCounts = actionFrameCounts
//
//        // Define the presentation style for the summary view.
//        modalPresentationStyle = .popover
//        modalTransitionStyle = .coverVertical
//
//        // Reestablish the video-processing chain when the user dismisses the
//        // summary view.
//        summaryVC.dismissalClosure = {
//            // Resume the video feed by enabling the camera when the summary
//            // view goes away.
//            self.videoCapture.isEnabled = true
//        }
//
//        // Present the summary view to the user.
//        present(summaryVC, animated: true)
//
//        // Stop the video feed by disabling the camera while showing the summary
//        // view.
//        videoCapture.isEnabled = false
//        authenticatePlayer()
        authenticateLocalPlayer()
        showLeaderBoard()
        videoCapture.isEnabled = false
    }
    
    func showLeaderBoard() {
        let gcVC = GKGameCenterViewController(state: .leaderboards)
        gcVC.gameCenterDelegate = self
        present(gcVC, animated: true)
    }
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
//        gameCenterViewController.dismiss(animated: true, completion: nil)
        gameCenterViewController.dismiss(animated: true) {
            self.videoCapture.isEnabled = true
        }
    }
    
}

// MARK: - Video Capture Delegate
extension MainViewController: VideoCaptureDelegate {
    /// Receives a video frame publisher from a video capture.
    /// - Parameters:
    ///   - videoCapture: A `VideoCapture` instance.
    ///   - framePublisher: A new frame publisher from the video capture.
    func videoCapture(_ videoCapture: VideoCapture,
                      didCreate framePublisher: FramePublisher) {
        updateUILabelsWithPrediction(.startingPrediction)
        
        // Build a new video-processing chain by assigning the new frame publisher.
        videoProcessingChain.upstreamFramePublisher = framePublisher
    }
}

// MARK: - video-processing chain Delegate
extension MainViewController: VideoProcessingChainDelegate {
    /// Receives an action prediction from a video-processing chain.
    /// - Parameters:
    ///   - chain: A video-processing chain.
    ///   - actionPrediction: An `ActionPrediction`.
    ///   - duration: The span of time the prediction represents.
    /// - Tag: detectedAction
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didPredict actionPrediction: ActionPrediction,
                              for frameCount: Int) {

        if actionPrediction.isModelLabel && actionPrediction.label != "Other Action" {
            // Update the total number of frames for this action.
            addFrameCount(frameCount, to: actionPrediction.label)
        }

        // Present the prediction in the UI.
        updateUILabelsWithPrediction(actionPrediction)
    }

    /// Receives a frame and any poses in that frame.
    /// - Parameters:
    ///   - chain: A video-processing chain.
    ///   - poses: A `Pose` array.
    ///   - frame: A video frame as a `CGImage`.
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didDetect poses: [Pose]?,
                              in frame: CGImage) {
        // Render the poses on a different queue than pose publisher.
        DispatchQueue.global(qos: .userInteractive).async {
            // Draw the poses onto the frame.
            self.drawPoses(poses, onto: frame)
        }
    }
}

// MARK: - Helper methods
extension MainViewController {
    /// Add the incremental duration to an action's total time.
    /// - Parameters:
    ///   - actionLabel: The name of the action.
    ///   - duration: The incremental duration of the action.
    private func addFrameCount(_ frameCount: Int, to actionLabel: String) {
        // Add the new duration to the current total, if it exists.
        let totalFrames = (actionFrameCounts[actionLabel] ?? 0) + 1 //frameCount

        // Assign the new total frame count for this action.
        actionFrameCounts[actionLabel] = totalFrames
    }

    /// Updates the user interface's labels with the prediction and its
    /// confidence.
    /// - Parameters:
    ///   - label: The prediction label.
    ///   - confidence: The prediction's confidence value.
    private func updateUILabelsWithPrediction(_ prediction: ActionPrediction) {
        // Update the UI's prediction label on the main thread.
        DispatchQueue.main.async {
//            self.actionLabel.text = prediction.label
            if prediction.label == "Not" {
                self.actionLabel.text = "Not Recognized"
            } else if prediction.label == "Push Up" {
                self.actionLabel.text = "Push Up!"
            } else if prediction.label == "Mistake - High" {
                self.actionLabel.text = "Lower hip to form a straight line with shoulder and legs"
            } else if prediction.label == "Mistake - Low" {
                self.actionLabel.text = "Lower shoulder to form a stright line with hip and legs"
            } else if prediction.label == "Mistake - Wide" {
                self.actionLabel.text = "Narrow arms to align directly under shoulder"
            } else {
                self.actionLabel.text = prediction.label
            }
        }

        // Update the UI's confidence label on the main thread.
        var confidenceString = prediction.confidenceString ?? "Observing..."
        if prediction.confidenceString != nil {
            if prediction.label == "Mistake - High" || prediction.label == "Mistake - Low" || prediction.label == "Mistake - Wide" {
                confidenceString = "0.0%"
            } else {
                confidenceString = "Confidence: " + confidenceString
            }
        }
        DispatchQueue.main.async {
            self.confidenceLabel.text = confidenceString
        }
        
        if prediction.label == "Push Up" {
            finishedExercise = true
            exerciseCount += 1
            
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "Daily-Count")+1, forKey: "Daily-Count")
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "Weekly-Count")+1, forKey: "Weekly-Count")
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "All-Time-Count")+1, forKey: "All-Time-Count")
            
            GKLeaderboard.submitScore(UserDefaults.standard.integer(forKey: "Daily-Count"), context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["daily_score"]) { _ in }
            GKLeaderboard.submitScore(UserDefaults.standard.integer(forKey: "Weekly-Count"), context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["weekly_score"]) { _ in }
            GKLeaderboard.submitScore(UserDefaults.standard.integer(forKey: "All-Time-Count"), context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["all_time_score"]) {error in
            }
            countLabel.text = "Count: " + String(exerciseCount)
        }
    }
    
    func saveHighScore(highScore: Int, leaderboardIdentifier: String) {
        if GKLocalPlayer.local.isAuthenticated {
        let scoreReporter = GKScore(leaderboardIdentifier: leaderboardIdentifier)
            scoreReporter.value = Int64(highScore)
            
           let scoreArray: [GKScore] = [scoreReporter]
            
            GKScore.report(scoreArray) { (error) in
                if error != nil {
                    print(error)
                } else {
                    print("Reported Successfully")
                }
            }
        }
    }

    /// Draws poses as wireframes on top of a frame, and updates the user
    /// interface with the final image.
    /// - Parameters:
    ///   - poses: An array of human body poses.
    ///   - frame: An image.
    /// - Tag: drawPoses
    private func drawPoses(_ poses: [Pose]?, onto frame: CGImage) {
        // Create a default render format at a scale of 1:1.
        let renderFormat = UIGraphicsImageRendererFormat()
        renderFormat.scale = 1.0

        // Create a renderer with the same size as the frame.
        let frameSize = CGSize(width: frame.width, height: frame.height)
        let poseRenderer = UIGraphicsImageRenderer(size: frameSize,
                                                   format: renderFormat)

        // Draw the frame first and then draw pose wireframes on top of it.
        let frameWithPosesRendering = poseRenderer.image { rendererContext in
            // The`UIGraphicsImageRenderer` instance flips the Y-Axis presuming
            // we're drawing with UIKit's coordinate system and orientation.
            let cgContext = rendererContext.cgContext

            // Get the inverse of the current transform matrix (CTM).
            let inverse = cgContext.ctm.inverted()

            // Restore the Y-Axis by multiplying the CTM by its inverse to reset
            // the context's transform matrix to the identity.
            cgContext.concatenate(inverse)

            // Draw the camera image first as the background.
            let imageRectangle = CGRect(origin: .zero, size: frameSize)
            cgContext.draw(frame, in: imageRectangle)

            // Create a transform that converts the poses' normalized point
            // coordinates `[0.0, 1.0]` to properly fit the frame's size.
            let pointTransform = CGAffineTransform(scaleX: frameSize.width,
                                                   y: frameSize.height)

            guard let poses = poses else { return }

            // Draw all the poses Vision found in the frame.
            for pose in poses {
                // Draw each pose as a wireframe at the scale of the image.
                pose.drawWireframeToContext(cgContext, applying: pointTransform)
            }
        }

        // Update the UI's full-screen image view on the main thread.
        DispatchQueue.main.async { self.imageView.image = frameWithPosesRendering }
    }
}
