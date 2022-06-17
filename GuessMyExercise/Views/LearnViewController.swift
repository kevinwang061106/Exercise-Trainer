//
//  LearnViewController.swift
//  Guess My Exercise
//
//  Created by Kevin Wang on 2022/5/12.
//  Copyright © 2022 Apple. All rights reserved.
//

import UIKit
import ARKit
import SceneKit

extension ARSCNView: ARSmartHitTest {}

class LearnViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet var trainStack: UIStackView!
    
    @IBOutlet var trainButton: UIButton!
    
    let focusNode = FocusSquare()
    var gameHasStarted = false
    var foundSurface = false
    var gamePos = SCNVector3Make(0.0, 0.0, 0.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        trainButton.layer.cornerRadius = 10
        trainButton.overrideUserInterfaceStyle = .dark
        self.focusNode.viewDelegate = sceneView
        sceneView.scene.rootNode.addChildNode(self.focusNode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !gameHasStarted {
            if focusNode.onPlane {
                gamePos = focusNode.position
                focusNode.isHidden = true
                gameHasStarted = true
                let scene = SCNScene(named: "art.scnassets/PushUp.scn")!
                let node = SCNNode()
                for child in scene.rootNode.childNodes {
                    node.addChildNode(child)
                }
                node.position = gamePos
                node.scale = SCNVector3(0.001, 0.001, 0.001)
                sceneView.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.focusNode.updateFocusNode()
        }
    }
    
}
