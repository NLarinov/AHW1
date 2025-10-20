//
//  ViewController.swift
//  AHW1
//

import UIKit

class ViewController: UIViewController {

    private let carView = CarView()
    private var carLeadingConstraint: NSLayoutConstraint?
    private var isDriving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startDrivingIfNeeded()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        carView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(carView)

        let offscreenDistance = UIScreen.main.bounds.width + 200
        carLeadingConstraint = carView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -offscreenDistance)

        NSLayoutConstraint.activate([
            carView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60)
        ])

        carLeadingConstraint?.isActive = true
    }

    private func startDrivingIfNeeded() {
        guard !isDriving else { return }
        isDriving = true
        view.layoutIfNeeded()
        drive(direction: .leftToRight)
    }

    private func drive(direction: CarView.Direction) {
        guard let leadingConstraint = carLeadingConstraint else { return }

        let carWidth = carView.bounds.width
        let screenWidth = view.bounds.width

        let startConstant: CGFloat
        let endConstant: CGFloat
        let transform: CGAffineTransform

        switch direction {
        case .leftToRight:
            startConstant = -carWidth
            endConstant = screenWidth
            transform = .identity
        case .rightToLeft:
            startConstant = screenWidth
            endConstant = -carWidth
            transform = CGAffineTransform(scaleX: -1, y: 1)
        }

        carView.updateDirection(direction)
        carView.transform = transform

        leadingConstraint.constant = startConstant
        view.layoutIfNeeded()
        carView.playWave(direction: direction)

        UIView.animate(withDuration: 4.0, delay: 0, options: [.curveLinear], animations: {
            leadingConstraint.constant = endConstant
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            guard let self else { return }
            let nextDirection: CarView.Direction = direction == .leftToRight ? .rightToLeft : .leftToRight
            self.drive(direction: nextDirection)
        })
    }
}
