//
//  NowPlayingViewController.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/22/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit
import MediaPlayer
import CoreMotion

//*****************************************************************
// NowPlayingViewControllerDelegate
//*****************************************************************

protocol NowPlayingViewControllerDelegate: class {
    func didPressPlayingButton()
    func didPressStopButton()
    func didPressNextButton()
    func didPressPreviousButton()
}

//*****************************************************************
// NowPlayingViewController
//*****************************************************************

class NowPlayingViewController: UIViewController {
    
    weak var delegate: NowPlayingViewControllerDelegate?

    // MARK: - IB UI
    
    @IBOutlet weak var albumHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var albumImageView: SpringImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var playingButton: UIButton!
    @IBOutlet weak var songLabel: SpringLabel!
    @IBOutlet weak var stationDescLabel: UILabel!
    @IBOutlet weak var volumeParentView: UIView!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    // MARK: - Properties
    
    var currentStation: RadioStation!
    var currentTrack: Track!
    
    var newStation = true
    var nowPlayingImageView: UIImageView!
    let radioPlayer = FRadioPlayer.shared
    
    var mpVolumeSlider: UISlider?
    
    
    // for Magnetic Field : ref. MagRadar
    let motionManager = CMMotionManager()
    let timeIntervalMagnetic: TimeInterval = 0.5
    var magVals:[Double] = [0,1,2,3]
    var magBase:[Double] = [0,0,0,0]
    var magDiff:[Double] = [0,0,0,0]
    let maxMagF: Double = 1000.0
    
    
    // for Auto Changing Station
    var timerStreamMonitor: Timer?
    var howManyCountOnProblem = 0
    let timeIntervalStream: TimeInterval = 5
    let maxCountForChangeStation = 4        // 5 * 4 = 20 secs
    
    
    //*****************************************************************
    // MARK: - ViewDidLoad
    //*****************************************************************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create Now Playing BarItem
        createNowPlayingAnimation()
        
        // Set AlbumArtwork Constraints
        optimizeForDeviceSize()

        // Set View Title
        self.title = currentStation.name
        
        // Set UI
        albumImageView.image = currentTrack.artworkImage
        stationDescLabel.text = currentStation.desc
        stationDescLabel.isHidden = currentTrack.artworkLoaded
        
        // Check for station change
        newStation ? stationDidChange() : playerStateDidChange(radioPlayer.state, animate: false)
        
        // Setup volumeSlider
        setupVolumeSlider()
        
        // Hide / Show Next/Previous buttons
        previousButton.isHidden = hideNextPreviousButtons
        nextButton.isHidden = hideNextPreviousButtons
        
        // for magnetic field
        self.startMagnetometerUpdates()
        
        // for auto changing station
        self.timerStreamMonitor = Timer(timeInterval: self.timeIntervalStream, target: self, selector: #selector(NowPlayingViewController.timerUpdate), userInfo: nil, repeats: true)
        RunLoop.main.add(self.timerStreamMonitor!, forMode: .defaultRunLoopMode)
        // CHK : self.timerMonitoring?.invalidate()
    }
    
    
    // MARK: -
    
    @objc func timerUpdate() {
        if self.howManyCountOnProblem >= self.maxCountForChangeStation {
            print( "Busy station or Network problem [\(self.currentStation.name)] : tapNextBtnByApp" )
            self.tapNextBtnByApp()
            self.howManyCountOnProblem = 0      // reset
        }
    }

    
    func startMagnetometerUpdates() {
        guard self.motionManager.isMagnetometerAvailable else {
            print( "not supported : detecting magnetic field." )
            return
        }
        
        self.motionManager.magnetometerUpdateInterval = self.timeIntervalMagnetic
        
        let queue = OperationQueue.current
        self.motionManager.startMagnetometerUpdates(to: queue!, withHandler: {
            (magnetometerData, error) in
            guard error == nil else {
                print(error!)
                return
            }
        
            if self.motionManager.isMagnetometerActive {
                if let magneticField = magnetometerData?.magneticField {
                    
                    let magStrengthDecimal = 4
                    
                    let magX = magneticField.x
                    let magY = magneticField.y
                    let magZ = magneticField.z
                    let magF = sqrt(pow(magX, 2)+pow(magY, 2)+pow(magZ, 2))
                    
                    self.magVals[0] = magX
                    self.magVals[1] = magY
                    self.magVals[2] = magZ
                    self.magVals[3] = magF
                    
                    self.magDiff[0] = magX - self.magBase[0]
                    self.magDiff[1] = magY - self.magBase[1]
                    self.magDiff[2] = magZ - self.magBase[2]
                    self.magDiff[3] = sqrt(pow(self.magDiff[0], 2)+pow(self.magDiff[1], 2)+pow(self.magDiff[2], 2))
                    
                    // magXView.text = String(format: "X:%0."+String(magStrengthDecimal)+"f uT", self.magDiff[0])
                    // magYView.text = String(format: "Y:%0."+String(magStrengthDecimal)+"f uT", self.magDiff[1])
                    // magZView.text = String(format: "Z:%0."+String(magStrengthDecimal)+"f uT", self.magDiff[2])
                    
                    let strMagF = String(format: "F:%0."+String(magStrengthDecimal)+"f uT", self.magDiff[3])
                    
                    if self.magDiff[3] >= self.maxMagF {
                        self.tapNextBtnByApp()
                        print( strMagF )
                    }
                    
                }
            }
        })
    }
    
    //*****************************************************************
    // MARK: - Setup
    //*****************************************************************
    
    func setupVolumeSlider() {
        // Note: This slider implementation uses a MPVolumeView
        // The volume slider only works in devices, not the simulator.
        for subview in MPVolumeView().subviews {
            guard let volumeSlider = subview as? UISlider else { continue }
            mpVolumeSlider = volumeSlider
        }
        
        guard let mpVolumeSlider = mpVolumeSlider else { return }
        
        volumeParentView.addSubview(mpVolumeSlider)
        
        mpVolumeSlider.translatesAutoresizingMaskIntoConstraints = false
        mpVolumeSlider.leftAnchor.constraint(equalTo: volumeParentView.leftAnchor).isActive = true
        mpVolumeSlider.rightAnchor.constraint(equalTo: volumeParentView.rightAnchor).isActive = true
        mpVolumeSlider.centerYAnchor.constraint(equalTo: volumeParentView.centerYAnchor).isActive = true
        
        mpVolumeSlider.setThumbImage(#imageLiteral(resourceName: "slider-ball"), for: .normal)
    }
    
    func stationDidChange() {
        radioPlayer.radioURL = URL(string: currentStation.streamURL)
        title = currentStation.name
    }
    
    //*****************************************************************
    // MARK: - Player Controls (Play/Pause/Volume)
    //*****************************************************************
    
    // Actions
    
    @IBAction func playingPressed(_ sender: Any) {
        delegate?.didPressPlayingButton()
    }
    
    @IBAction func stopPressed(_ sender: Any) {
        delegate?.didPressStopButton()
    }
    
    @IBAction func nextPressed(_ sender: Any) {
        delegate?.didPressNextButton()
    }
    
    
    func tapNextBtnByApp() {
        self.howManyCountOnProblem = 0          // reset
        self.magBase = self.magVals             // magnetic calibrate.
        self.nextPressed(self.nextButton)
    }
    
    
    @IBAction func previousPressed(_ sender: Any) {
        delegate?.didPressPreviousButton()
    }
    
    //*****************************************************************
    // MARK: - Load station/track
    //*****************************************************************
    
    func load(station: RadioStation?, track: Track?, isNewStation: Bool = true) {
        guard let station = station else { return }
        
        currentStation = station
        currentTrack = track
        newStation = isNewStation
    }
    
    func updateTrackMetadata(with track: Track?) {
        guard let track = track else { return }
        
        currentTrack.artist = track.artist
        currentTrack.title = track.title
        
        updateLabels()
    }
    
    // Update track with new artwork
    func updateTrackArtwork(with track: Track?) {
        guard let track = track else { return }
        
        // Update track struct
        currentTrack.artworkImage = track.artworkImage
        currentTrack.artworkLoaded = track.artworkLoaded
        
        albumImageView.image = currentTrack.artworkImage
        
        if track.artworkLoaded {
            // Animate artwork
            albumImageView.animation = "wobble"
            albumImageView.duration = 2
            albumImageView.animate()
            stationDescLabel.isHidden = true
        } else {
            stationDescLabel.isHidden = false
        }
        
        // Force app to update display
        view.setNeedsDisplay()
    }
    
    private func isPlayingDidChange(_ isPlaying: Bool) {
        playingButton.isSelected = isPlaying
        startNowPlayingAnimation(isPlaying)
    }
    
    
    // MARK: -
    
    func playbackStateDidChange(_ playbackState: FRadioPlaybackState, animate: Bool) {
        
        let message: String?
        
        switch playbackState {
        case .paused:
            message = "Station Paused... : \(self.currentStation.name)"
            self.howManyCountOnProblem += 1
            if self.howManyCountOnProblem >= 3 { print( message ?? "" ) }
        case .playing:
            message = nil
            self.howManyCountOnProblem = 0      // reset
        case .stopped:
            message = "Station Stopped... : \(self.currentStation.name)"
            self.howManyCountOnProblem += 1
            if self.howManyCountOnProblem >= 3 { print( message ?? "" ) }
        }
        
        updateLabels(with: message, animate: animate)
        isPlayingDidChange(radioPlayer.isPlaying)
    }
    
    func playerStateDidChange(_ state: FRadioPlayerState, animate: Bool) {
        
        let message: String?
        
        switch state {
        case .loading:
            message = "Loading Station ..."
        case .urlNotSet:
            message = "Station URL not valide"
        case .readyToPlay, .loadingFinished:
            playbackStateDidChange(radioPlayer.playbackState, animate: animate)
            return
        case .error:
            message = "Error Playing"
        }
        
        updateLabels(with: message, animate: animate)
    }
    
    //*****************************************************************
    // MARK: - UI Helper Methods
    //*****************************************************************
    
    func optimizeForDeviceSize() {
        
        // Adjust album size to fit iPhone 4s, 6s & 6s+
        let deviceHeight = self.view.bounds.height
        
        if deviceHeight == 480 {
            albumHeightConstraint.constant = 106
            view.updateConstraints()
        } else if deviceHeight == 667 {
            albumHeightConstraint.constant = 230
            view.updateConstraints()
        } else if deviceHeight > 667 {
            albumHeightConstraint.constant = 260
            view.updateConstraints()
        }
    }
    
    func updateLabels(with statusMessage: String? = nil, animate: Bool = true) {

        guard let statusMessage = statusMessage else {
            // Radio is (hopefully) streaming properly
            songLabel.text = currentTrack.title
            artistLabel.text = currentTrack.artist
            shouldAnimateSongLabel(animate)
            return
        }
        
        // There's a an interruption or pause in the audio queue
        
        // Update UI only when it's not aleary updated
        guard songLabel.text != statusMessage else { return }
        
        songLabel.text = statusMessage
        artistLabel.text = currentStation.name
    
        if animate {
            songLabel.animation = "flash"
            songLabel.repeatCount = 3
            songLabel.animate()
        }
    }
    
    // Animations
    
    func shouldAnimateSongLabel(_ animate: Bool) {
        // Animate if the Track has album metadata
        guard animate, currentTrack.title != currentStation.name else { return }
        
        // songLabel animation
        songLabel.animation = "zoomIn"
        songLabel.duration = 1.5
        songLabel.damping = 1
        songLabel.animate()
    }
    
    func createNowPlayingAnimation() {
        
        // Setup ImageView
        nowPlayingImageView = UIImageView(image: UIImage(named: "NowPlayingBars-3"))
        nowPlayingImageView.autoresizingMask = []
        nowPlayingImageView.contentMode = UIViewContentMode.center
        
        // Create Animation
        nowPlayingImageView.animationImages = AnimationFrames.createFrames()
        nowPlayingImageView.animationDuration = 0.7
        
        // Create Top BarButton
        let barButton = UIButton(type: .custom)
        barButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        barButton.addSubview(nowPlayingImageView)
        nowPlayingImageView.center = barButton.center
        
        let barItem = UIBarButtonItem(customView: barButton)
        self.navigationItem.rightBarButtonItem = barItem
    }
    
    func startNowPlayingAnimation(_ animate: Bool) {
        animate ? nowPlayingImageView.startAnimating() : nowPlayingImageView.stopAnimating()
    }
    
    //*****************************************************************
    // MARK: - Segue
    //*****************************************************************
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "InfoDetail", let infoController = segue.destination as? InfoDetailViewController else { return }
        infoController.currentStation = currentStation
    }
    
    @IBAction func infoButtonPressed(_ sender: UIButton) {
        performSegue(withIdentifier: "InfoDetail", sender: self)
    }
    
    @IBAction func shareButtonPressed(_ sender: UIButton) {
        let songToShare = "I'm listening to \(currentTrack.title) on \(currentStation.name) via Swift Radio Pro"
        let activityViewController = UIActivityViewController(activityItems: [songToShare, currentTrack.artworkImage!], applicationActivities: nil)
        activityViewController.completionWithItemsHandler = {(activityType: UIActivityType?, completed:Bool, returnedItems:[Any]?, error: Error?) in
            if completed {
                // do something on completion if you want
            }
        }
        present(activityViewController, animated: true, completion: nil)
    }
}
