import UIKit

class ViewController: UIViewController {

    // Outlets

    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var roundLabel: UILabel!

    // Game values

    var currentValue = 50
    var targetValue = 0
    var score = 0
    var round = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        configureSliderAppearance()
        startNewGame()
    }

    // Actions

    @IBAction func showAlert() {
        let difference = abs(targetValue - currentValue)
        var points = 100 - difference

        let title: String

        if difference == 0 {
            title = "Perfect!"
            points += 100
        } else if difference == 1 {
            title = "You almost had it!"
            points += 50
        } else if difference < 5 {
            title = "You almost had it!"
        } else if difference < 10 {
            title = "Pretty good!"
        } else {
            title = "Not even close..."
        }

        score += points

        let message = """
        Target: \(targetValue)
        Your value: \(currentValue)
        You were off by \(difference).
        You scored \(points) points.
        """

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        let action = UIAlertAction(
            title: "OK",
            style: .default
        ) { [weak self] _ in
            self?.startNewRound()
        }

        alert.addAction(action)
        present(alert, animated: true)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        currentValue = Int(sender.value.rounded())
    }

    @IBAction func startNewGame() {
        score = 0
        round = 0
        startNewRound()

        let transition = CATransition()
        transition.type = .fade
        transition.duration = 1.0
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer.add(transition, forKey: nil)
    }

    //Game methods

    func startNewRound() {
        round += 1
        targetValue = Int.random(in: 1...100)
        currentValue = 50

        slider.value = Float(currentValue)

        updateLabels()
    }

    func updateLabels() {
        targetLabel.text = String(targetValue)
        scoreLabel.text = String(score)
        roundLabel.text = String(round)
    }

    //Slider appearance

    func configureSliderAppearance() {
        if let normalThumb = UIImage(named: "SliderThumb-Normal") {
            slider.setThumbImage(normalThumb, for: .normal)
        }

        if let highlightedThumb = UIImage(
            named: "SliderThumb-Highlighted"
        ) {
            slider.setThumbImage(
                highlightedThumb,
                for: .highlighted
            )
        }

        let insets = UIEdgeInsets(
            top: 0,
            left: 14,
            bottom: 0,
            right: 14
        )

        if let leftImage = UIImage(named: "SliderTrackLeft") {
            let resizableImage = leftImage.resizableImage(
                withCapInsets: insets
            )

            slider.setMinimumTrackImage(
                resizableImage,
                for: .normal
            )
        }

        if let rightImage = UIImage(named: "SliderTrackRight") {
            let resizableImage = rightImage.resizableImage(
                withCapInsets: insets
            )

            slider.setMaximumTrackImage(
                resizableImage,
                for: .normal
            )
        }
    }
}
