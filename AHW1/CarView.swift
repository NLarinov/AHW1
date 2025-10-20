//
//  CarView.swift
//  AHW1
//

import UIKit

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

private enum CarViewConstants {
    static let capsuleHeights: [CGFloat] = [80, 100, 90, 100, 90, 100, 100, 100, 100, 90, 100, 80, 80, 60]
    static let capsuleWidth: CGFloat = 16
    static let capsuleSpacing: CGFloat = 10
    static let capsuleCornerRadius: CGFloat = 10
    static let capsuleAboveWheelInset: CGFloat = 16
    
    static let capsulesAboveWheels: [Int] = [2, 3, 4, 9, 10, 11]

    static let wheelSize: CGFloat = 60
    static let wheelCornerRadius: CGFloat = 20
    static let innerWheelCornerRadius: CGFloat = 10
    static let innerWheelScale: CGFloat = 0.6
    static let wheelHorizontalInset: CGFloat = 56

    static let waveHeight: CGFloat = 14
    static let waveDuration: CFTimeInterval = 0.5
    static let waveDelayStep: CFTimeInterval = 0.15
    static let waveKeyTimes: [NSNumber] = [0, 0.8, 1]
    static let waveTimingFunctions: [CAMediaTimingFunction] = [
        CAMediaTimingFunction(name: .easeInEaseOut),
        CAMediaTimingFunction(name: .easeInEaseOut)
    ]

    static let wheelRotationDuration: CFTimeInterval = 2
    static let wheelRotationTurns: CGFloat = 2 * .pi

    static var capsuleAboveWheelOffset: CGFloat {
        wheelSize - capsuleAboveWheelInset
    }

    static var waveAnimationValues: [CGFloat] {
        [0, -waveHeight, 0]
    }
}

final class CarView: UIView {

    enum Direction {
        case leftToRight
        case rightToLeft

        var rotationSign: CGFloat {
            switch self {
            case .leftToRight:
                return -1
            case .rightToLeft:
                return 1
            }
        }
    }

    private struct CapsuleItem {
        let capsule: UIView
        let container: UIView
        let bottomConstraint: NSLayoutConstraint
    }

    private lazy var capsuleItems: [CapsuleItem] = CarViewConstants.capsuleHeights.enumerated().map { index, height in
        let capsule = UIView()
        capsule.translatesAutoresizingMaskIntoConstraints = false
        capsule.backgroundColor = UIColor.systemBlue
        capsule.layer.cornerRadius = CarViewConstants.capsuleCornerRadius
        capsule.clipsToBounds = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = false

        container.addSubview(capsule)

        let bottomConstant: CGFloat = CarViewConstants.capsulesAboveWheels.contains(index) ? -CarViewConstants.capsuleAboveWheelOffset : 0
        let bottomConstraint = capsule.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: bottomConstant)

        NSLayoutConstraint.activate([
            capsule.widthAnchor.constraint(equalToConstant: CarViewConstants.capsuleWidth),
            capsule.heightAnchor.constraint(equalToConstant: height),
            capsule.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bottomConstraint,
            container.widthAnchor.constraint(equalTo: capsule.widthAnchor)
        ])

        return CapsuleItem(capsule: capsule, container: container, bottomConstraint: bottomConstraint)
    }

    private lazy var capsuleViews: [UIView] = capsuleItems.map(\.capsule)

    private lazy var capsuleBottomConstraints: [NSLayoutConstraint] = capsuleItems.map(\.bottomConstraint)

    private lazy var bodyStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: capsuleItems.map(\.container))
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.spacing = CarViewConstants.capsuleSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var leftWheel = WheelView(size: CarViewConstants.wheelSize)
    private lazy var rightWheel = WheelView(size: CarViewConstants.wheelSize)

    private var currentDirection: Direction = .rightToLeft

    private static let wheelRotationKey = "wheelRotation"
    private static let waveAnimationKeyPrefix = "wave-"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViewHierarchy()
        setupConstraints()
        applyWheelRotation(for: currentDirection)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewHierarchy()
        setupConstraints()
        applyWheelRotation(for: currentDirection)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCapsuleVerticalOffsets()
    }

    private func setupViewHierarchy() {
        backgroundColor = .clear

        addSubview(bodyStackView)
        addSubview(leftWheel)
        addSubview(rightWheel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            bodyStackView.topAnchor.constraint(equalTo: topAnchor),
            bodyStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bodyStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyStackView.bottomAnchor.constraint(equalTo: leftWheel.centerYAnchor),

            leftWheel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: CarViewConstants.wheelHorizontalInset),
            leftWheel.bottomAnchor.constraint(equalTo: bottomAnchor),

            rightWheel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -CarViewConstants.wheelHorizontalInset),
            rightWheel.bottomAnchor.constraint(equalTo: bottomAnchor),
            rightWheel.centerYAnchor.constraint(equalTo: leftWheel.centerYAnchor)
        ])
    }

    func updateDirection(_ direction: Direction) {
        guard direction != currentDirection else { return }
        currentDirection = direction
        applyWheelRotation(for: direction)
    }

    func playWave(direction: Direction) {
        let baseTime = CACurrentMediaTime()

        let capsulesWithPosition = capsuleViews.map { capsule -> (UIView, CGFloat) in
            let centerInSuperview = capsule.convert(CGPoint(x: capsule.bounds.midX, y: capsule.bounds.midY), to: self)
            return (capsule, centerInSuperview.x)
        }

        let sortedCapsules = capsulesWithPosition.sorted { $0.1 > $1.1 }.map { $0.0 }

        for (offset, capsule) in sortedCapsules.enumerated() {
            guard let index = capsuleViews.firstIndex(where: { $0 === capsule }) else { continue }
            let key = "\(CarView.waveAnimationKeyPrefix)\(index)"
            capsule.layer.removeAnimation(forKey: key)
            let animation = makeWaveAnimation(beginTime: baseTime + CFTimeInterval(offset) * CarViewConstants.waveDelayStep)
            capsule.layer.add(animation, forKey: key)
        }
    }

    private func makeWaveAnimation(beginTime: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = CarViewConstants.waveAnimationValues
        animation.keyTimes = CarViewConstants.waveKeyTimes
        animation.duration = CarViewConstants.waveDuration
        animation.beginTime = beginTime
        animation.timingFunctions = CarViewConstants.waveTimingFunctions
        animation.isAdditive = true
        return animation
    }

    private func applyWheelRotation(for direction: Direction) {
        let wheelViews = [leftWheel, rightWheel]
        wheelViews.forEach { wheel in
            wheel.layer.removeAnimation(forKey: CarView.wheelRotationKey)
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.byValue = CarViewConstants.wheelRotationTurns
            animation.duration = CarViewConstants.wheelRotationDuration
            animation.repeatCount = .infinity
            animation.isCumulative = true
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
            wheel.layer.add(animation, forKey: CarView.wheelRotationKey)
        }
    }

    private func updateCapsuleVerticalOffsets() {
        for (index, _) in capsuleViews.enumerated() {
            guard let constraint = capsuleBottomConstraints[safe: index] else { continue }
            
            let targetConstant: CGFloat
            if CarViewConstants.capsulesAboveWheels.contains(index) {
                targetConstant = -CarViewConstants.capsuleAboveWheelOffset
            } else {
                targetConstant = 0
            }
            
            if abs(constraint.constant - targetConstant) > .ulpOfOne {
                constraint.constant = targetConstant
            }
        }
    }
}

private final class WheelView: UIView {

    private let innerWheel = UIView()
    private let wheelSize: CGFloat

    init(size: CGFloat) {
        self.wheelSize = size
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        self.wheelSize = CarViewConstants.wheelSize
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.systemBlue
        layer.cornerRadius = CarViewConstants.wheelCornerRadius
        clipsToBounds = true

        innerWheel.translatesAutoresizingMaskIntoConstraints = false
        innerWheel.backgroundColor = .white
        innerWheel.layer.cornerRadius = CarViewConstants.innerWheelCornerRadius
        innerWheel.clipsToBounds = true

        addSubview(innerWheel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: wheelSize),
            heightAnchor.constraint(equalToConstant: wheelSize),

            innerWheel.centerXAnchor.constraint(equalTo: centerXAnchor),
            innerWheel.centerYAnchor.constraint(equalTo: centerYAnchor),
            innerWheel.widthAnchor.constraint(equalToConstant: wheelSize * CarViewConstants.innerWheelScale),
            innerWheel.heightAnchor.constraint(equalTo: innerWheel.widthAnchor)
        ])
    }
}
