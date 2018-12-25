//
//  ViewController.swift
//  SampleProject
//
//  Created by Jack Amoratis on 12/13/18.
//  Copyright © 2018 John Amoratis. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    @IBOutlet weak var liveView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var imageUIView: UIImageView!
    @IBOutlet weak var tryToRecognizeButton: UIButton!
    @IBOutlet weak var analyticsResultCollectionView: UICollectionView!
    
    
    var collectionViewDataSource : BehaviorSubject<[AnalyzedObject]>!
    
    var recognizeObjectUseCase : RecognizeObjectUseCase!
    
    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recognizeObjectUseCase = RecognizeObjectUseCase()
        
        _ = tryToRecognizeButton.rx.tap
            .subscribe { [weak self] x in
                print("object tapped")
                self?.tryToRecognizeButton.isHidden = true
                self!.recognizeObjectUseCase.buttonTapped()
        }
        
        _ = recognizeObjectUseCase.analyzedObject
            .subscribe (onNext: { n in
                var currentVal = try! self.collectionViewDataSource.value()
                currentVal.append(n)
                try! self.collectionViewDataSource.onNext(currentVal)
                self.analyticsResultCollectionView.scrollToBottom()
            })
        
        tryToRecognizeButton.isHidden = true
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        liveView.layer.addSublayer(recognizeObjectUseCase.previewLayer)
        
        
        
        
        
        var width = liveView.frame.width
        var height = liveView.frame.height
        
        var calcWidth: Double = Double(liveView.frame.height * 0.81)
        var x = (Double(liveView.frame.width) * 0.5) - ( calcWidth * 0.5)
        print(liveView.frame.width)
        
        recognizeObjectUseCase.previewLayer.frame = CGRect(x: x, y: 0, width: calcWidth, height: Double(height))
        
        let frameWidth = recognizeObjectUseCase.previewLayer.frame.width
        
        let maskView = UIView(frame: CGRect(x: recognizeObjectUseCase.previewLayer.frame.minX, y: recognizeObjectUseCase.previewLayer.frame.minY, width: frameWidth, height: frameWidth))
        maskView.backgroundColor = .blue
        maskView.layer.cornerRadius = 100
        liveView.mask = maskView
        
        
        
        var collectionViewDataArray: [AnalyzedObject] = []
        collectionViewDataSource = BehaviorSubject<[AnalyzedObject]>(value: collectionViewDataArray)
        analyticsResultCollectionView.register(UINib(nibName: "AnalyticResultCell", bundle: nil), forCellWithReuseIdentifier: "Cell")
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.itemSize = CGSize(width: 220, height: 220)
        analyticsResultCollectionView.setCollectionViewLayout(collectionViewLayout, animated: true)
        collectionViewDataSource.bind(to: analyticsResultCollectionView.rx.items(cellIdentifier: "Cell", cellType: AnalyticResultCell.self)) { index, model, cell in
                cell.backImage.image = model.image
                cell.label.text = model.labelText
            }
            .disposed(by: disposeBag)
        
        _ = analyticsResultCollectionView.rx.willBeginDragging
        .subscribe { [weak self] x in
            self?.tryToRecognizeButton.isHidden = false
            self?.recognizeObjectUseCase.setActivityState(to: "paused")
        }
        
        
    }
}

extension UICollectionView {
    func scrollToBottom(animated: Bool = true) {
        let sections = self.numberOfSections
        let items = self.numberOfItems(inSection: sections - 1)
        print("how many items: \(items)")
        if (items > 0){
            self.scrollToItem(at: IndexPath(row: items - 1, section: sections - 1) as IndexPath, at: .right, animated: true)
        }else{
            print("Not enough items")
        }
    }
}
